"""Read-only providers. Failed reads never certify an inventory as complete."""
import errno
import json
import os
from pathlib import Path
import re
import sqlite3
import time
from collections import OrderedDict
from contextlib import closing
from urllib.parse import quote
from .parsers import (stamp, text_content, clean_request, request, delivered_state,
                      parse_claude, parse_codex_legacy, BACKGROUND_TASK_MAX_QUIET_SECONDS)
from .jsonl import read_jsonl

HOME = Path.home()
CODEX_HOME = None
CLAUDE_HOME = None
DISABLED_PROVIDERS = set()
PATHS = {}
PATHS_AT = 0
PAGINATED_CACHE = OrderedDict()

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


class SourceBatch(list):
    def __init__(self):
        super().__init__()
        self.inventory_complete = True
        self.issues = []

    def failed(self, error):
        self.inventory_complete = False
        self.issues.append(read_failure(error)[0])


def claude_cards(cutoff, tracked_ids=()):
    global PATHS_AT, PATHS
    if time.time() - PATHS_AT > 60:
        PATHS = {p.stem: p for p in (claude_root() / "projects").glob("*/*.jsonl")}
        PATHS_AT = time.time()
    base = HOME / "Library/Application Support/Claude/claude-code-sessions"
    if not base.exists():
        raise FileNotFoundError("Claude Code session store not found")
    cards = SourceBatch()
    # os.walk's error callback preserves denied subdirectories; Path.rglob may skip them.
    paths = []
    for directory, _, files in os.walk(base, onerror=cards.failed):
        paths.extend(Path(directory) / name for name in files if name.endswith(".json"))
    for path in paths:
        try:
            meta = json.loads(path.read_text())
            if not isinstance(meta, dict):
                raise ValueError("Invalid session metadata")
            sid = meta.get("sessionId")
            if not sid or not meta.get("cliSessionId"):
                continue
            updated = stamp(meta.get("lastActivityAt", meta.get("createdAt")))
            if updated < cutoff and "claude:" + sid not in tracked_ids:
                continue
        except (ValueError, OSError, TypeError) as error:
            cards.failed(error)
            continue
        issue = None
        try:
            parsed = read_jsonl(PATHS.get(meta["cliSessionId"]), parse_claude)
            if parsed[2] in ("History unavailable", "History temporarily unavailable"):
                issue = parsed[2]
        except (ValueError, OSError, TypeError, KeyError) as error:
            issue = read_failure(error)[0]
            parsed = ([], "unknown", "History temporarily unavailable", "", 0, "")
        link = "claude://code/continue?session=" + quote(sid, safe="") if sid.startswith("local_") else "claude://code/" + quote(sid, safe="")
        card = base_card("claude", sid, meta.get("title") or "Untitled conversation", meta.get("originCwd") or meta.get("cwd"), updated, parsed, link)
        if issue:
            card["observationIssue"] = issue
        cards.append(card)
    return cards



def codex_paginated(con, tid, generation=None):
    cache_key = (generation, tid)
    if generation is not None and cache_key in PAGINATED_CACHE:
        PAGINATED_CACHE.move_to_end(cache_key)
        return PAGINATED_CACHE[cache_key]
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
    result = requests, state, reason, response, when, turn["turn_id"] + ":" + turn["status"]
    if generation is not None:
        PAGINATED_CACHE[cache_key] = result
        PAGINATED_CACHE.move_to_end(cache_key)
        while len(PAGINATED_CACHE) > 256:
            PAGINATED_CACHE.popitem(last=False)
    return result


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
    history_generation = None
    history_issue = None
    if any(x["history_mode"] == "paginated" for x in rows):
        try:
            path = codex_root() / "thread_history_1.sqlite"
            history_generation = database_generation(path)
            history = readonly(path)
            history.execute("BEGIN")
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
                        parsed = codex_paginated(history, row["id"], history_generation)
                else:
                    parsed = read_jsonl(row["rollout_path"], parse_codex_legacy)
            except (OSError, sqlite3.Error, ValueError, KeyError, TypeError, UnsupportedFormat) as error:
                issue, retryable = read_failure(error)
                if isinstance(error, sqlite3.Error) and retryable:
                    # A busy shared database affects all its histories. Reopen it
                    # once per attempt, rather than timing out on every card.
                    raise
                parsed = ([], "unknown", "History temporarily unavailable", "", 0, "")
            if parsed[2] in ("History unavailable", "History temporarily unavailable"):
                issue = issue or parsed[2]
            title = row["name"] or titles.get(row["id"]) or (row["title"].splitlines() or ["Untitled conversation"])[0]
            card = base_card("codex", row["id"], title, row["cwd"], row["updated_at"], parsed, "codex://threads/" + row["id"])
            if issue:
                card["observationIssue"] = issue
            cards.append(card)
    finally:
        if history:
            history.close()
    return cards


def database_generation(path):
    signatures = []
    for member in (path, Path(str(path) + "-wal")):
        try:
            s = member.stat()
            signatures.append((str(member), s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns))
        except FileNotFoundError:
            signatures.append((str(member), None))
    return tuple(signatures)


def scan_provider(provider, days=14, tracked_ids=()):
    cutoff = time.time() - days * 86400
    if provider in DISABLED_PROVIDERS:
        return {"cards": [], "health": {"status": "disabled"}, "inventoryComplete": False,
                "knownIDs": [], "scannedAt": time.time()}
    reader = claude_cards if provider == "claude" else codex_cards
    for attempt in range(3):
        found, complete, retryable = [], False, False
        try:
            found = reader(cutoff, tracked_ids)
            complete = getattr(found, "inventory_complete", True)
            issues = getattr(found, "issues", []) + [c["observationIssue"] for c in found if c.get("observationIssue")]
            health = {"status": "partial" if issues else "connected"}
            if issues:
                health["issue"] = issues[0]
            retryable = any(issue in ("History database busy", "History database could not be opened", "Session files not found", "Too many open files") for issue in issues)
        except (OSError, sqlite3.Error, ValueError, KeyError, TypeError, UnsupportedFormat) as error:
            detail, retryable = read_failure(error)
            health = {"status": {"Access denied": "accessDenied", "Unsupported format": "unsupported"}.get(detail, "unavailable"), "issue": detail}
            if isinstance(error, FileNotFoundError):
                names = ["Claude.app"] if provider == "claude" else ["Codex.app", "ChatGPT.app"]
                installed = any((base / name).exists() for base in [Path("/Applications"), HOME / "Applications"] for name in names)
                if provider == "codex" and list(codex_root().glob("state_*.sqlite")):
                    health = {"status": "unsupported", "issue": "Session database version changed"}
                else:
                    health = {"status": "noSessions" if installed else "notInstalled"}
                retryable = False
        if not retryable or attempt == 2:
            return {"cards": list(found), "health": health, "inventoryComplete": complete,
                    "knownIDs": [c["id"] for c in found], "scannedAt": time.time()}
        time.sleep((0.2, 0.6)[attempt])


def scan(days=14, tracked_ids=()):
    """Human-readable diagnostic snapshot; the app uses the typed worker protocol."""
    cards, health = [], {}
    for provider in ("claude", "codex"):
        result = scan_provider(provider, days, tracked_ids)
        cards.extend(result["cards"])
        status = result["health"]["status"]
        labels = {"connected": "Connected", "partial": "Unavailable", "disabled": "Disabled",
                  "notInstalled": "Not installed", "noSessions": "No local sessions",
                  "accessDenied": "Access denied", "unsupported": "Unsupported format", "unavailable": "Unavailable"}
        label = labels[status]
        issue = result["health"].get("issue")
        health[provider] = label + (" · " + issue if issue and issue != label else "")
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


