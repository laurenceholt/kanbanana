"""Read-only native-session adapters. Stdout is a private JSON pipe to the app.

No native stores are written. Unknown state stays unknown. Cache by file signature
to avoid rereading unchanged histories. No credentials, reasoning, or tool output
are returned to the UI or to GPT.
"""
import argparse
import datetime as dt
import errno
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import sys
import time
from contextlib import closing
from urllib.parse import quote

HOME = Path.home()
CODEX_HOME = None
CLAUDE_HOME = None
DISABLED_PROVIDERS = set()

class UnsupportedFormat(Exception):
    pass

def codex_root():
    return CODEX_HOME or HOME / ".codex"

def claude_root():
    return CLAUDE_HOME or HOME / ".claude"

def require_columns(con, table, columns):
    actual = {row[1] for row in con.execute("PRAGMA table_info(" + table + ")")}
    if not set(columns) <= actual:
        raise UnsupportedFormat()
CACHE = {}
PATHS = {}
PATHS_AT = 0
BACKGROUND_TASK_MAX_QUIET_SECONDS = 24 * 60 * 60


def stamp(value):
    if isinstance(value, (int, float)):
        return value / 1000 if value > 100000000000 else value
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
    except (TypeError, ValueError, AttributeError):
        return 0


def text_content(value):
    if isinstance(value, str):
        return value
    if isinstance(value, list):
        return "\n".join(x.get("text", "") for x in value if isinstance(x, dict) and x.get("type") in ("text", "input_text", "output_text"))
    return ""


def clean_request(text):
    # Metadata can be encoded as a user-role item. Do not manufacture a request.
    stripped = text.strip()
    while stripped.startswith("<in-app-browser-context"):
        end = stripped.find("</in-app-browser-context>")
        if end < 0:
            return ""
        stripped = stripped[end + len("</in-app-browser-context>"):].strip()
    if stripped.startswith(("<environment_context>", "<permissions instructions>", "<realtime_delegation>", "<turn_aborted>", "<task-notification>", "# AGENTS.md instructions")):
        return ""
    return stripped


def request(key, text, when):
    return {"id": str(key), "text": text, "time": when}


def delivered_state(text):
    """Conservative signals of required input, not a general completion judge.

    Inspect only assistant prose. Questions inside quotes, code or proposed
    messages, and optional 'would you like me to' offers remain delivered.
    """
    prose = re.sub(r"```.*?```", "", text or "", flags=re.S)
    prose = "\n".join(line for line in prose.splitlines() if not line.lstrip().startswith(">"))
    prose = re.sub(r'“[^”]*”|"[^"\n]*"|`[^`]*`', "", prose)
    prose = re.sub(r"\[([^]]+)\]\([^)]*\)", r"\1", prose)
    prose = re.sub(r"[*_#]", "", prose).replace("’", "'").strip()
    tail = prose[-1600:].lower()
    paused = re.search(r"\b(?:i(?:'m| am|'ll| will)?|we(?:'re| are|'ll| will)?)\s+(?:now\s+)?(?:waiting|wait|pausing|pause|stopping|stop|paused|blocked)(?:\s+here)?\s+(?:for|until|on|pending)\s+(?:your\s+(?:review|approval|confirmation|answer|input|choice|decision)|you\s+(?:to\s+)?(?:confirm|approve|answer|choose|reply|decide))", tail)
    prerequisite = re.search(r"\b(?:i|we)\s+(?:need|require)\s+your\s+(?:approval|confirmation|answer|input|choice|decision)\b[^.!?\n]{0,120}\bbefore\s+(?:i|we)\s+(?:can\s+)?(?:continue|proceed|start|run|build|finish|send|publish)", tail)
    if paused or prerequisite:
        return "needsMe", "Waiting for your input"
    # A response consisting of a short, direct clarification question, with no
    # delivery or optional next-step offer. Longer/mixed responses stay ready.
    if len(prose.split()) <= 65 and prose.endswith("?") and re.match(r"^(?:which|what|where|when|how many|could you clarify|can you confirm)\b", prose, re.I) and not re.search(r"\b(?:done|completed|built|delivered|finished|suggest|optional)\b", prose, re.I):
        return "needsMe", "Question"
    return "ready", "Response ready"


def parse_claude(records):
    requests, seen = [], set()
    pending_tasks = {}
    state, reason, response, event_time, event_id = "unknown", "Status unavailable", "", 0, ""
    for index, item in enumerate(records):
        if item.get("isSidechain"):
            continue
        typ = item.get("type")
        when = stamp(item.get("timestamp"))
        msg = item.get("message") or {}
        key = item.get("uuid") or str(index)
        if typ == "user":
            content = msg.get("content", "")
            is_tool = isinstance(content, list) and any(x.get("type") == "tool_result" for x in content if isinstance(x, dict))
            task_events = []
            result = item.get("toolUseResult")
            if is_tool and isinstance(result, dict):
                if result.get("isAsync") and result.get("status") == "async_launched" and result.get("agentId"):
                    task_events.append((result["agentId"], "running"))
                # Shell work has a different launch envelope from agents. It
                # can still be running after the parent sends an end_turn
                # progress update, even if TaskOutput has never been called.
                if result.get("backgroundTaskId"):
                    task_events.append((result["backgroundTaskId"], "running"))
                # TaskOutput and typed notifications settle either kind of task.
                task = result.get("task")
                if isinstance(task, dict) and task.get("task_id"):
                    task_events.append((task["task_id"], task.get("status")))
            origin = item.get("origin")
            if isinstance(origin, dict) and origin.get("kind") == "task-notification" and isinstance(content, str):
                # Read only the transport envelope. Quoted XML in a user's
                # ordinary request must not finish a real background task.
                envelope = content.strip().split("</task-notification>", 1)[0]
                if envelope.startswith("<task-notification>"):
                    task_id = re.search(r"<task-id>([^<]+)</task-id>", envelope)
                    status = re.search(r"<status>([^<]+)</status>", envelope)
                    if task_id and status:
                        task_events.append((task_id[1].strip(), status[1].strip()))
            for task_id, status in task_events:
                if status in ("running", "pending", "in_progress"):
                    pending_tasks[task_id] = when
                    state, reason, response = "running", "Waiting for background task", ""
                    event_time, event_id = when or event_time, key
                elif status in ("completed", "failed", "stopped", "killed", "cancelled") and task_id in pending_tasks:
                    pending_tasks.pop(task_id)
                    # Child completion wakes the parent; it is not itself the
                    # parent's delivery. Wait for its subsequent final response.
                    state = "running" if status == "completed" else "needsMe"
                    reason = "" if status == "completed" else "Background task failed" if status == "failed" else "Background task stopped"
                    response = ""
                    event_time, event_id = when or event_time, key
            if not is_tool and not item.get("isMeta"):
                text = clean_request(text_content(content))
                if text and key not in seen:
                    # An old orphaned task must not attach itself to a new day's
                    # request after the conversation has gone quiet.
                    pending_tasks = {task_id: launched for task_id, launched in pending_tasks.items() if when - launched <= BACKGROUND_TASK_MAX_QUIET_SECONDS}
                    requests.append(request(key, text, when)); seen.add(key)
                    state, reason, response = "running", "", ""
                    event_time, event_id = when, key
        elif typ == "assistant":
            blocks = msg.get("content", [])
            if not isinstance(blocks, list):
                continue
            event_time, event_id = when or event_time, key
            tools = [x.get("name") for x in blocks if isinstance(x, dict) and x.get("type") == "tool_use"]
            if "AskUserQuestion" in tools:
                state, reason = "needsMe", "Question"
            elif tools:
                state, reason = "running", ""
            output = text_content(blocks)
            if msg.get("stop_reason") == "end_turn" and output and "AskUserQuestion" not in tools:
                state, reason = delivered_state(output)
                response = output
            if item.get("isApiErrorMessage"):
                state, reason = "needsMe", "Agent error"
        if pending_tasks and state in ("running", "ready"):
            state, reason, response = "running", "Waiting for background task", ""
    return requests, state, reason, response, event_time, event_id


def parse_codex_legacy(records):
    requests, seen = [], set()
    input_call = None
    state, reason, response, event_time, event_id = "unknown", "Status unavailable", "", 0, ""
    for index, item in enumerate(records):
        p = item.get("payload") or {}
        typ, kind = item.get("type"), p.get("type")
        when = stamp(item.get("timestamp"))
        key = p.get("id") or str(index)
        # response_item contains canonical user messages. event_msg user_message is
        # its duplicate transport representation and must not add a second entry.
        if typ == "response_item" and kind == "message" and p.get("role") == "user":
            text = clean_request(text_content(p.get("content")))
            if text and key not in seen:
                requests.append(request(key, text, when)); seen.add(key)
        if typ == "event_msg":
            if kind in ("task_started", "user_message"):
                input_call = None
                state, reason, response = "running", "", ""
                event_time, event_id = when, str(index)
            elif kind in ("task_complete", "turn_complete"):
                response = p.get("last_agent_message") or response
                state, reason = delivered_state(response)
                event_time, event_id = when, str(index)
            elif kind in ("turn_aborted", "error"):
                state, reason = "needsMe", "Interrupted" if kind == "turn_aborted" else "Agent error"
                event_time, event_id = when, str(index)
        if typ == "response_item" and kind == "message" and p.get("role") == "assistant" and p.get("phase") == "final_answer":
            response = text_content(p.get("content"))
            if state == "ready":
                state, reason = delivered_state(response)
        if typ == "response_item" and kind == "function_call" and p.get("name", "").split(".")[-1] == "request_user_input":
            input_call = p.get("call_id")
            state, reason = "needsMe", "Question"
            event_time, event_id = when, key
        elif typ == "response_item" and kind == "function_call_output" and input_call and p.get("call_id") == input_call:
            input_call = None
            state, reason = "running", ""
            event_time, event_id = when, key
    return requests, state, reason, response, event_time, event_id


def read_jsonl(path, parser):
    if not path or not Path(path).is_file():
        return [], "unknown", "History unavailable", "", 0, ""
    p = Path(path)
    sig = (p.stat().st_mtime_ns, p.stat().st_size)
    if str(p) in CACHE and CACHE[str(p)][0] == sig:
        return CACHE[str(p)][1]
    records = []
    with p.open() as f:
        for line in f:
            try:
                records.append(json.loads(line))
            except (ValueError, UnicodeDecodeError):
                continue  # A streaming tail may not yet be a complete JSON record.
    parsed = parser(records)
    CACHE[str(p)] = (sig, parsed)
    return parsed


def readonly(path):
    # Preserve OS access-denied / missing-file errors instead of flattening them to SQLite open failures.
    with Path(path).open("rb"):
        pass
    con = sqlite3.connect(Path(path).as_uri() + "?mode=ro", uri=True, timeout=0.5)
    try:
        con.row_factory = sqlite3.Row
        con.execute("PRAGMA query_only=ON")
    except Exception:
        con.close()
        raise
    return con


def read_failure(error):
    """Safe, actionable details; never include SQL, paths or conversation text."""
    if isinstance(error, UnsupportedFormat):
        return "Unsupported format", False
    message = str(error).lower()
    if isinstance(error, sqlite3.Error):
        if "locked" in message or "busy" in message:
            return "History database busy", True
        if "unable to open" in message:
            return "History database could not be opened", True
        if "no such table" in message or "no such column" in message:
            return "Unsupported format", False
        return "History database read failed", False
    if isinstance(error, OSError):
        if error.errno in (errno.EACCES, errno.EPERM):
            return "Access denied", False
        if error.errno in (errno.EMFILE, errno.ENFILE):
            return "Too many open files", True
        if isinstance(error, FileNotFoundError):
            return "Session files not found", True
        return "Session files temporarily unreadable", True
    return "History record could not be read", False


def base_card(provider, native_id, title, folder, updated, parsed, link):
    requests, state, reason, response, event_time, event_id = parsed
    # A persisted unfinished turn isn't proof it is still alive days later.
    # An explicit outstanding task remains pending between log writes. The
    # parent's end_turn can just be an update while that task is working.
    if state == "running":
        waiting = reason == "Waiting for background task"
        age = time.time() - (max(updated, event_time) if waiting else event_time)
        if age > (BACKGROUND_TASK_MAX_QUIET_SECONDS if waiting else 120):
            state, reason = "unknown", "Background task has no recent activity" if waiting else "No recent execution signal"
    return {"id": provider + ":" + native_id, "provider": provider, "nativeID": native_id,
            "title": title[:240] or "Untitled conversation", "folder": folder or "",
            "updated": max(updated, event_time), "requests": requests,
            "state": state, "reason": reason, "response": response[-20000:],
            "eventID": event_id, "eventTime": event_time, "url": link}


def claude_cards(cutoff, tracked_ids=()):
    global PATHS_AT, PATHS
    if time.time() - PATHS_AT > 60:
        PATHS = {p.stem: p for p in (claude_root() / "projects").glob("*/*.jsonl")}
        PATHS_AT = time.time()
    base = HOME / "Library/Application Support/Claude/claude-code-sessions"
    if not base.exists():
        raise FileNotFoundError("Claude Code session store not found")
    cards = []
    for p in base.rglob("*.json"):
        try:
            meta = json.loads(p.read_text())
            sid = meta.get("sessionId")
            if not sid or not meta.get("cliSessionId"):
                continue
            updated = stamp(meta.get("lastActivityAt", meta.get("createdAt")))
            if updated < cutoff and "claude:" + sid not in tracked_ids:
                continue
            parsed = read_jsonl(PATHS.get(meta["cliSessionId"]), parse_claude)
            # Local Desktop sessions have a different route from cloud sessions.
            link = "claude://code/continue?session=" + quote(sid, safe="") if sid.startswith("local_") else "claude://code/" + quote(sid, safe="")
            cards.append(base_card("claude", sid, meta.get("title") or "Untitled conversation", meta.get("originCwd") or meta.get("cwd"), updated, parsed, link))
        except (ValueError, OSError):
            continue
    return cards


def codex_paginated(con, tid):
    require_columns(con, "thread_items", ["item_id", "created_at_ms", "item_json", "thread_id", "turn_id", "item_type", "rollout_ordinal"])
    require_columns(con, "thread_turns", ["thread_id", "turn_id", "status", "completed_at", "started_at", "rollout_ordinal"])
    rows = con.execute("SELECT item_id,created_at_ms,item_json FROM thread_items WHERE thread_id=? AND item_type IN ('userMessage','agentMessage') ORDER BY rollout_ordinal", (tid,))
    requests, seen, response = [], set(), ""
    for row in rows:
        d = json.loads(row["item_json"])
        if d.get("type") == "userMessage":
            text = clean_request(text_content(d.get("content")))
            if text and row["item_id"] not in seen:
                requests.append(request(row["item_id"], text, stamp(row["created_at_ms"])))
                seen.add(row["item_id"])
        elif d.get("phase") == "final_answer":
            response = d.get("text", "")
    turn = con.execute("SELECT * FROM thread_turns WHERE thread_id=? ORDER BY rollout_ordinal DESC LIMIT 1", (tid,)).fetchone()
    if not turn:
        return requests, "unknown", "Status unavailable", response, 0, ""
    state = {"completed": "ready", "failed": "needsMe", "interrupted": "needsMe", "inProgress": "running"}.get(turn["status"], "unknown")
    reason = {"completed": "Response ready", "failed": "Agent error", "interrupted": "Interrupted"}.get(turn["status"], "")
    if state == "ready":
        state, reason = delivered_state(response)
    when = stamp(turn["completed_at"] or turn["started_at"])
    if state == "running":
        latest = con.execute("SELECT MAX(created_at_ms) FROM thread_items WHERE thread_id=? AND turn_id=?", (tid, turn["turn_id"])).fetchone()[0]
        when = max(when, stamp(latest))
        for row in con.execute("SELECT item_json FROM thread_items WHERE thread_id=? AND turn_id=? AND item_type IN ('mcpToolCall','dynamicToolCall')", (tid, turn["turn_id"])):
            item = json.loads(row[0])
            if item.get("status") == "inProgress" and item.get("tool", "").split(".")[-1] == "request_user_input":
                state, reason = "needsMe", "Question"
                break
    return requests, state, reason, response, when, turn["turn_id"] + ":" + turn["status"]


def codex_cards(cutoff, tracked_ids=()):
    # Do not silently read an obsolete database left behind by a source upgrade.
    for path in codex_root().glob("state_*.sqlite"):
        version = re.fullmatch(r"state_(\d+)\.sqlite", path.name)
        if version and int(version[1]) > 5:
            raise UnsupportedFormat()
    cards = []
    titles = {}
    index = codex_root() / "session_index.jsonl"
    if index.exists():
        for line in index.read_text().splitlines():
            try:
                item = json.loads(line)
                if item.get("thread_name"):
                    titles[item["id"]] = item["thread_name"]
            except (ValueError, KeyError):
                continue
    # sqlite3's transaction context does not close its connection. Polling must
    # release handles explicitly instead of waiting for cyclic garbage collection.
    with closing(readonly(codex_root() / "state_5.sqlite")) as con:
        require_columns(con, "threads", ["id", "name", "title", "cwd", "updated_at", "history_mode", "rollout_path", "source", "thread_source"])
        rows = con.execute("SELECT id,name,title,cwd,updated_at,history_mode,rollout_path FROM threads WHERE source IN ('vscode','appServer','cli') AND (thread_source IS NULL OR thread_source='user')").fetchall()
        # Filter inexpensive metadata first; read histories only for recent or
        # already tracked conversations, including older parked cards.
        rows = [row for row in rows if row["updated_at"] >= cutoff or "codex:" + row["id"] in tracked_ids]
    history = None
    history_issue = None
    if any(x["history_mode"] == "paginated" for x in rows):
        try:
            history = readonly(codex_root() / "thread_history_1.sqlite")
        except (OSError, sqlite3.Error) as error:
            history_issue = read_failure(error)[0]
    try:
        for row in rows:
            issue = None
            try:
                if row["history_mode"] == "paginated":
                    if history is None:
                        parsed = ([], "unknown", "History temporarily unavailable", "", 0, "")
                        issue = history_issue
                    else:
                        parsed = codex_paginated(history, row["id"])
                else:
                    parsed = read_jsonl(row["rollout_path"], parse_codex_legacy)
            except (OSError, sqlite3.Error, ValueError, KeyError, TypeError, UnsupportedFormat) as error:
                issue, retryable = read_failure(error)
                if isinstance(error, sqlite3.Error) and retryable:
                    # A busy shared database affects all its histories. Reopen it
                    # once per attempt, rather than timing out on every card.
                    raise
                parsed = ([], "unknown", "History temporarily unavailable", "", 0, "")
            title = row["name"] or titles.get(row["id"]) or (row["title"].splitlines() or ["Untitled conversation"])[0]
            card = base_card("codex", row["id"], title, row["cwd"], row["updated_at"], parsed, "codex://threads/" + row["id"])
            if issue:
                card["observationIssue"] = issue
            cards.append(card)
    finally:
        if history:
            history.close()
    return cards


def scan(days=14, tracked_ids=()):
    cards, health = [], {}
    cutoff = time.time() - days * 86400
    for provider, reader in [("claude", claude_cards), ("codex", codex_cards)]:
        if provider in DISABLED_PROVIDERS:
            health[provider] = "Disabled"
            continue
        for attempt in range(3):
            found = []
            try:
                found = reader(cutoff, tracked_ids)
                issues = [c["observationIssue"] for c in found if c.get("observationIssue")]
                health[provider] = "Connected · " + str(len(found)) + " conversations" + (" · " + str(len(issues)) + " histories unavailable: " + issues[0] if issues else "")
                retryable = any(issue in ("History database busy", "History database could not be opened", "Session files not found", "Too many open files") for issue in issues)
            except (OSError, sqlite3.Error, ValueError, KeyError, UnsupportedFormat) as error:
                detail, retryable = read_failure(error)
                if detail in ("Unsupported format", "Access denied"):
                    health[provider] = detail
                elif isinstance(error, FileNotFoundError) or (isinstance(error, sqlite3.Error) and not (codex_root() / "state_5.sqlite").exists()):
                    app_names = ["Claude.app"] if provider == "claude" else ["Codex.app", "ChatGPT.app"]
                    installed = any((base / name).exists() for base in [Path("/Applications"), HOME / "Applications"] for name in app_names)
                    # A newer database is a schema change, not a missing installation.
                    if provider == "codex" and list(codex_root().glob("state_*.sqlite")):
                        health[provider] = "Unsupported format · session database version changed"
                    else:
                        health[provider] = "No local sessions" if installed else "Not installed"
                    retryable = False
                else:
                    health[provider] = "Unavailable · " + detail
            if not retryable or attempt == 2:
                cards.extend(found)
                break
            time.sleep((0.2, 0.6)[attempt])
    return {"cards": cards, "health": health, "scannedAt": time.time()}


class HealthLog:
    """Bounded local diagnostics: counts and safe errors, no requests or IDs."""
    def __init__(self, path):
        self.path = Path(path)
        try:
            self.events = [event for event in json.loads(self.path.read_text())[-50:] if isinstance(event, dict)][-50:]
        except (OSError, ValueError, TypeError):
            self.events = []

    def record(self, snapshot):
        event = {"health": dict(snapshot["health"]), "states": {provider: {state: sum(c["provider"] == provider and c["state"] == state for c in snapshot["cards"]) for state in ("running", "needsMe", "ready", "unknown")} for provider in ("claude", "codex")}}
        if self.events and all(self.events[-1].get(k) == v for k, v in event.items()):
            return
        event["at"] = snapshot["scannedAt"]
        self.events = (self.events + [event])[-50:]
        temporary = self.path.with_name(self.path.name + "." + str(os.getpid()) + ".tmp")
        try:
            temporary.write_text(json.dumps(self.events, indent=2))
            temporary.chmod(0o600)
            temporary.replace(self.path)
        except OSError:
            pass  # A diagnostic write must never stop status monitoring.


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--days", type=int, default=14)
    parser.add_argument("--parent-pid", type=int)
    parser.add_argument("--tracked-id", action="append", default=[])
    parser.add_argument("--health-log")
    parser.add_argument("--disable-provider", choices=["claude", "codex"], action="append", default=[])
    parser.add_argument("--codex-home", type=Path)
    parser.add_argument("--claude-home", type=Path)
    args = parser.parse_args()
    DISABLED_PROVIDERS = set(args.disable_provider)
    CODEX_HOME = args.codex_home
    CLAUDE_HOME = args.claude_home
    tracked_ids = set(args.tracked_id)
    health_log = HealthLog(args.health_log) if args.health_log else None
    while True:
        if args.parent_pid and os.getppid() != args.parent_pid:
            break
        snapshot = scan(args.days, tracked_ids)
        tracked_ids.update(c["id"] for c in snapshot["cards"])
        if health_log:
            health_log.record(snapshot)
        print(json.dumps(snapshot, ensure_ascii=False), flush=True)
        if not args.watch:
            break
        time.sleep(4)
