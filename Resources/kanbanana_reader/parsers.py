"""Pure incremental classification. No filesystem, network, or UI dependencies."""
import datetime as dt
import re

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


class ClaudeParser:
    def __init__(self):
        self.requests, self.seen = [], set()
        self.pending_tasks = {}
        self.state, self.reason, self.response, self.event_time, self.event_id = "unknown", "Status unavailable", "", 0, ""
        self.index = -1

    def feed(self, item):
        self.index += 1
        if item.get("isSidechain"):
            return
        typ = item.get("type")
        when = stamp(item.get("timestamp"))
        msg = item.get("message") or {}
        key = item.get("uuid") or str(self.index)
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
                    self.pending_tasks[task_id] = when
                    self.state, self.reason, self.response = "running", "Waiting for background task", ""
                    self.event_time, self.event_id = when or self.event_time, key
                elif status in ("completed", "failed", "stopped", "killed", "cancelled") and task_id in self.pending_tasks:
                    self.pending_tasks.pop(task_id)
                    # Child completion wakes the parent; it is not itself the
                    # parent's delivery. Wait for its subsequent final response.
                    self.state = "running" if status == "completed" else "needsMe"
                    self.reason = "" if status == "completed" else "Background task failed" if status == "failed" else "Background task stopped"
                    self.response = ""
                    self.event_time, self.event_id = when or self.event_time, key
            if not is_tool and not item.get("isMeta"):
                text = clean_request(text_content(content))
                if text and key not in self.seen:
                    # An old orphaned task must not attach itself to a new day's
                    # request after the conversation has gone quiet.
                    self.pending_tasks = {task_id: launched for task_id, launched in self.pending_tasks.items() if when - launched <= BACKGROUND_TASK_MAX_QUIET_SECONDS}
                    self.requests.append(request(key, text, when)); self.seen.add(key)
                    self.state, self.reason, self.response = "running", "", ""
                    self.event_time, self.event_id = when, key
        elif typ == "assistant":
            blocks = msg.get("content", [])
            if not isinstance(blocks, list):
                return
            self.event_time, self.event_id = when or self.event_time, key
            tools = [x.get("name") for x in blocks if isinstance(x, dict) and x.get("type") == "tool_use"]
            if "AskUserQuestion" in tools:
                self.state, self.reason = "needsMe", "Question"
            elif tools:
                self.state, self.reason = "running", ""
            output = text_content(blocks)
            if msg.get("stop_reason") == "end_turn" and output and "AskUserQuestion" not in tools:
                self.state, self.reason = delivered_state(output)
                self.response = output
            if item.get("isApiErrorMessage"):
                self.state, self.reason = "needsMe", "Agent error"
        if self.pending_tasks and self.state in ("running", "ready"):
            self.state, self.reason, self.response = "running", "Waiting for background task", ""

    def result(self):
        return (self.requests, self.state, self.reason, self.response, self.event_time, self.event_id)


def parse_claude(records):
    parser = ClaudeParser()
    for item in records:
        parser.feed(item)
    return parser.result()

class CodexParser:
    def __init__(self):
        self.requests, self.seen = [], set()
        self.input_call = None
        self.state, self.reason, self.response, self.event_time, self.event_id = "unknown", "Status unavailable", "", 0, ""
        self.index = -1

    def feed(self, item):
        self.index += 1
        p = item.get("payload") or {}
        typ, kind = item.get("type"), p.get("type")
        when = stamp(item.get("timestamp"))
        key = p.get("id") or str(self.index)
        # response_item contains canonical user messages. event_msg user_message is
        # its duplicate transport representation and must not add a second entry.
        if typ == "response_item" and kind == "message" and p.get("role") == "user":
            text = clean_request(text_content(p.get("content")))
            if text and key not in self.seen:
                self.requests.append(request(key, text, when)); self.seen.add(key)
        if typ == "event_msg":
            if kind in ("task_started", "user_message"):
                self.input_call = None
                self.state, self.reason, self.response = "running", "", ""
                self.event_time, self.event_id = when, str(self.index)
            elif kind in ("task_complete", "turn_complete"):
                self.response = p.get("last_agent_message") or self.response
                self.state, self.reason = delivered_state(self.response)
                self.event_time, self.event_id = when, str(self.index)
            elif kind in ("turn_aborted", "error"):
                self.state, self.reason = "needsMe", "Interrupted" if kind == "turn_aborted" else "Agent error"
                self.event_time, self.event_id = when, str(self.index)
        if typ == "response_item" and kind == "message" and p.get("role") == "assistant" and p.get("phase") == "final_answer":
            self.response = text_content(p.get("content"))
            if self.state == "ready":
                self.state, self.reason = delivered_state(self.response)
        if typ == "response_item" and kind == "function_call" and p.get("name", "").split(".")[-1] == "request_user_input":
            self.input_call = p.get("call_id")
            self.state, self.reason = "needsMe", "Question"
            self.event_time, self.event_id = when, key
        elif typ == "response_item" and kind == "function_call_output" and self.input_call and p.get("call_id") == self.input_call:
            self.input_call = None
            self.state, self.reason = "running", ""
            self.event_time, self.event_id = when, key

    def result(self):
        return (self.requests, self.state, self.reason, self.response, self.event_time, self.event_id)


def parse_codex_legacy(records):
    parser = CodexParser()
    for item in records:
        parser.feed(item)
    return parser.result()
