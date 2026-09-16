import importlib.util
import json
from pathlib import Path
import sqlite3
import subprocess
import os
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("reader", Path(__file__).parents[1] / "Resources/reader.py")
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)


class ReaderTests(unittest.TestCase):
    def test_required_input_is_distinct_from_optional_followups_and_quoted_questions(self):
        for text in [
            "Which repository should I use?",
            "I’m stopping here for your review before the formal study search.",
            "I need your approval before I can publish this.",
            "I've drafted the plan. I'll wait for you to confirm before building it.",
        ]:
            self.assertEqual(r.delivered_state(text)[0], "needsMe", text)
        for text in [
            "Built the interactive. Would you like me to test it?",
            "Done. If you want, I can also add examples.",
            'Suggested ask: “Which repository should I use?”',
            '> I am waiting for your approval.\n\nThat was yesterday; it is done now.',
            '```\nI need your approval before I can publish.\n```\nExample added.',
            "I'm not waiting for your input; the build is running.",
            "Done. [Documentation](https://example.test/?x=1)",
        ]:
            self.assertEqual(r.delivered_state(text)[0], "ready", text)

    def test_claude_question_tool_cannot_be_overwritten_by_end_turn_text(self):
        record = self.final_response(text="Choose the target repository.")
        record["message"]["content"].append({"type": "tool_use", "name": "AskUserQuestion", "id": "question"})
        self.assertEqual(r.parse_claude([record])[1:3], ("needsMe", "Question"))
        self.assertEqual(r.parse_claude([self.final_response(text="Which repository should I use?")])[1], "needsMe")

    def test_codex_input_tool_waits_then_resumes_on_matching_answer(self):
        question = {"type": "response_item", "timestamp": 100, "payload": {"type": "function_call", "name": "functions.request_user_input", "call_id": "ask"}}
        other = {"type": "response_item", "timestamp": 101, "payload": {"type": "function_call_output", "call_id": "other"}}
        answer = {"type": "response_item", "timestamp": 102, "payload": {"type": "function_call_output", "call_id": "ask"}}
        self.assertEqual(r.parse_codex_legacy([question, other])[1], "needsMe")
        self.assertEqual(r.parse_codex_legacy([question, other, answer])[1], "running")
        finish = {"type": "event_msg", "timestamp": 103, "payload": {"type": "task_complete", "last_agent_message": "I am waiting for your confirmation."}}
        self.assertEqual(r.parse_codex_legacy([finish])[1:3], ("needsMe", "Waiting for your input"))

    def test_codex_paginated_required_input_and_live_question_lifecycle(self):
        with sqlite3.connect(":memory:") as con:
            con.row_factory = sqlite3.Row
            con.execute("CREATE TABLE thread_items (thread_id TEXT,turn_id TEXT,item_id TEXT,created_at_ms INTEGER,item_json TEXT,item_type TEXT,rollout_ordinal INTEGER)")
            con.execute("CREATE TABLE thread_turns (thread_id TEXT,turn_id TEXT,status TEXT,started_at INTEGER,completed_at INTEGER,rollout_ordinal INTEGER)")
            con.execute("INSERT INTO thread_turns VALUES ('thread','turn','completed',100,110,1)")
            final = {"type": "agentMessage", "phase": "final_answer", "text": "I'm stopping here for your review before the formal study search."}
            con.execute("INSERT INTO thread_items VALUES ('thread','turn','final',110,?,'agentMessage',1)", (json.dumps(final),))
            self.assertEqual(r.codex_paginated(con, "thread")[1:3], ("needsMe", "Waiting for your input"))
            final["text"] = "Done. Would you like me to add tests?"
            con.execute("UPDATE thread_items SET item_json=?", (json.dumps(final),))
            self.assertEqual(r.codex_paginated(con, "thread")[1], "ready")
            con.execute("UPDATE thread_turns SET status='inProgress',completed_at=NULL")
            tool = {"type": "mcpToolCall", "tool": "request_user_input", "status": "inProgress"}
            con.execute("INSERT INTO thread_items VALUES ('thread','turn','tool',111,?,'mcpToolCall',2)", (json.dumps(tool),))
            self.assertEqual(r.codex_paginated(con, "thread")[1:3], ("needsMe", "Question"))
            tool["status"] = "completed"
            con.execute("UPDATE thread_items SET item_json=? WHERE item_id='tool'", (json.dumps(tool),))
            self.assertEqual(r.codex_paginated(con, "thread")[1], "running")

    def test_transient_provider_failure_reopens_and_recovers_with_bounded_retries(self):
        card = r.base_card("codex", "a", "Title", "", 100, ([], "ready", "Response ready", "", 100, "turn"), "codex://threads/a")
        with patch.object(r, "claude_cards", return_value=[]), patch.object(r, "codex_cards", side_effect=[sqlite3.OperationalError("database is locked"), [card]]) as reader, patch.object(r.time, "sleep") as sleep:
            snapshot = r.scan()
            self.assertEqual(snapshot["cards"], [card])
            self.assertTrue(snapshot["health"]["codex"].startswith("Connected"))
            self.assertEqual(reader.call_count, 2)
            sleep.assert_called_once_with(0.2)
        with patch.object(r, "claude_cards", return_value=[]), patch.object(r, "codex_cards", side_effect=sqlite3.OperationalError("database is locked")) as reader, patch.object(r.time, "sleep"):
            snapshot = r.scan()
            self.assertEqual(reader.call_count, 3)
            self.assertEqual(snapshot["health"]["codex"], "Unavailable · History database busy")

    def test_permanent_failure_is_specific_and_does_not_retry_or_expose_details(self):
        with patch.object(r, "claude_cards", return_value=[]), patch.object(r, "codex_cards", side_effect=sqlite3.OperationalError("no such table: private_table_name")) as reader, patch.object(r.time, "sleep") as sleep:
            snapshot = r.scan()
            self.assertEqual(reader.call_count, 1)
            sleep.assert_not_called()
            self.assertEqual(snapshot["health"]["codex"], "Unsupported format")
            self.assertNotIn("private_table_name", json.dumps(snapshot))

    def test_polling_closes_metadata_database_connections(self):
        with tempfile.TemporaryDirectory() as d, patch.object(r, "HOME", Path(d)):
            root = Path(d) / ".codex"; root.mkdir()
            with sqlite3.connect(root / "state_5.sqlite") as con:
                con.execute("CREATE TABLE threads (id TEXT,name TEXT,title TEXT,cwd TEXT,updated_at INTEGER,history_mode TEXT,rollout_path TEXT,source TEXT,thread_source TEXT)")
            opened = []
            original = r.readonly
            def track(path):
                con = original(path); opened.append(con); return con
            with patch.object(r, "readonly", side_effect=track):
                for _ in range(10):
                    self.assertEqual(r.codex_cards(0), [])
            self.assertEqual(len(opened), 10)
            for con in opened:
                with self.assertRaises(sqlite3.ProgrammingError):
                    con.execute("SELECT 1")

    def test_health_log_is_bounded_private_and_survives_restart(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "health.json"
            log = r.HealthLog(path)
            snapshot = {"cards": [{"id": "private-id", "provider": "codex", "title": "private-title", "requests": [{"text": "private-request"}], "state": "ready"}], "health": {"codex": "Connected"}, "scannedAt": 100}
            for n in range(60):
                snapshot["health"]["codex"] = "Connected" if n % 2 else "Unavailable · History database busy"
                snapshot["scannedAt"] = n
                log.record(snapshot)
            text = path.read_text()
            self.assertEqual(len(json.loads(text)), 50)
            self.assertNotIn("private-", text)
            restarted = r.HealthLog(path)
            restarted.record(snapshot)
            self.assertEqual(path.read_text(), text, "An unchanged observation should not add a log event")
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_claude_desktop_cards_use_local_session_navigation(self):
        with tempfile.TemporaryDirectory() as d, patch.object(r, "HOME", Path(d)), patch.object(r, "PATHS", {}), patch.object(r, "PATHS_AT", 0):
            root = Path(d) / "Library/Application Support/Claude/claude-code-sessions"
            root.mkdir(parents=True)
            sid = "local_550e8400-e29b-41d4-a716-446655440000"
            (root / "session.json").write_text(json.dumps({"sessionId": sid, "cliSessionId": "cli-transcript-id", "title": "Renamed conversation", "lastActivityAt": 100}))
            card = r.claude_cards(0)[0]
            self.assertEqual(card["nativeID"], sid)
            self.assertEqual(card["url"], "claude://code/continue?session=" + sid)

    def test_tracked_claude_history_is_rechecked_outside_discovery_window(self):
        with tempfile.TemporaryDirectory() as d, patch.object(r, "HOME", Path(d)), patch.object(r, "PATHS", {}), patch.object(r, "PATHS_AT", 0):
            root = Path(d) / "Library/Application Support/Claude/claude-code-sessions"
            root.mkdir(parents=True)
            logs = Path(d) / ".claude/projects/example"; logs.mkdir(parents=True)
            for sid, updated in [("recent", 100), ("old", 10), ("untracked", 10)]:
                (root / (sid + ".json")).write_text(json.dumps({"sessionId": sid, "cliSessionId": sid, "lastActivityAt": updated}))
                (logs / (sid + ".jsonl")).write_text(json.dumps({"type": "assistant", "uuid": sid, "timestamp": updated, "message": {"stop_reason": "end_turn", "content": [{"type": "text", "text": "Done"}]}}) + "\n")
            cards = r.claude_cards(50, {"claude:old", "codex:untracked"})
            self.assertEqual({c["nativeID"] for c in cards}, {"recent", "old"})
            self.assertTrue(all(c["state"] == "ready" for c in cards))
            # Exercise the actual fresh-process retry boundary and CLI flag.
            output = subprocess.check_output([sys.executable, str(Path(r.__file__)), "--days", "14", "--tracked-id", "claude:old"], env={**os.environ, "HOME": d}, text=True, timeout=10)
            retried = json.loads(output)
            self.assertEqual([c["nativeID"] for c in retried["cards"]], ["old"])
            self.assertEqual(retried["cards"][0]["state"], "ready")

    def test_tracked_codex_history_is_rechecked_without_importing_unrelated_history(self):
        with tempfile.TemporaryDirectory() as d, patch.object(r, "HOME", Path(d)):
            root = Path(d) / ".codex"; root.mkdir()
            rollout = root / "done.jsonl"
            rollout.write_text(json.dumps({"type": "event_msg", "payload": {"type": "task_complete", "last_agent_message": "Done"}}) + "\n")
            with sqlite3.connect(root / "state_5.sqlite") as con:
                con.execute("CREATE TABLE threads (id TEXT,name TEXT,title TEXT,cwd TEXT,updated_at INTEGER,history_mode TEXT,rollout_path TEXT,source TEXT,thread_source TEXT)")
                con.executemany("INSERT INTO threads VALUES (?,?,?,?,?,?,?,?,?)", [(sid, sid, sid, "/one", updated, "rollout", str(rollout), "vscode", "user") for sid, updated in [("recent", 100), ("old", 10), ("untracked", 10)]])
            cards = r.codex_cards(50, {"codex:old", "claude:untracked"})
            self.assertEqual({c["nativeID"] for c in cards}, {"recent", "old"})
            self.assertTrue(all(c["state"] == "ready" for c in cards))

    def user(self, key, text, **extra):
        return dict(type="user", uuid=key, timestamp="2026-09-08T12:00:00Z", message={"content": text}, **extra)

    def async_agent(self, task_id):
        return self.user("launch-" + task_id, [{"type": "tool_result", "tool_use_id": "tool-" + task_id, "content": "Private tool output"}], toolUseResult={"isAsync": True, "status": "async_launched", "agentId": task_id, "prompt": "Private child prompt"})

    def async_shell(self, task_id):
        return self.user("launch-" + task_id, [{"type": "tool_result", "tool_use_id": "tool-" + task_id, "content": "Private command output"}], toolUseResult={"stdout": "", "stderr": "", "interrupted": False, "backgroundTaskId": task_id, "backgroundCwdHint": "/private/project"})

    def task_notification(self, task_id, status="completed"):
        return self.user("notify-" + task_id, f"<task-notification>\n<task-id>{task_id}</task-id>\n<status>{status}</status>\n<summary>Private child summary</summary>\n</task-notification>", origin={"kind": "task-notification"})

    def final_response(self, key="final", text="The build agent is working; I will send it when verified."):
        return {"type": "assistant", "uuid": key, "timestamp": "2026-09-08T12:00:01Z", "message": {"stop_reason": "end_turn", "content": [{"type": "text", "text": text}]}}

    def test_claude_background_agent_outlasts_parent_end_turn_and_quiet_period(self):
        records = [self.user("request", "Build the interactive"), self.async_agent("builder"), self.final_response()]
        parsed = r.parse_claude(records)
        self.assertEqual(parsed[1:4], ("running", "Waiting for background task", ""))
        self.assertEqual([x["id"] for x in parsed[0]], ["request"])
        self.assertNotIn("Private", json.dumps(parsed))
        with patch.object(r.time, "time", return_value=parsed[4] + 15 * 60):
            card = r.base_card("claude", "test", "L12", "", 100, parsed, "")
        self.assertEqual(card["state"], "running", "An explicit pending task must not expire between log writes")

    def test_claude_old_orphan_is_unknown_and_does_not_attach_to_a_new_request(self):
        records = [self.user("request", "Build it"), self.async_agent("orphan"), self.final_response()]
        parsed = r.parse_claude(records)
        with patch.object(r.time, "time", return_value=parsed[4] + 25 * 3600):
            card = r.base_card("claude", "test", "Old job", "", 100, parsed, "")
        self.assertEqual(card["state"], "unknown", "Do not claim an abandoned background task is running forever")
        new = self.user("new-request", "Build something else"); new["timestamp"] = "2026-09-10T12:00:00Z"
        final = self.final_response("new-final", "Delivered."); final["timestamp"] = "2026-09-10T12:01:00Z"
        self.assertEqual(r.parse_claude(records + [new, final])[1], "ready")

    def test_claude_waits_for_all_children_then_parent_delivery(self):
        records = [self.user("request", "Build it"), self.async_agent("a"), self.async_agent("b"), self.final_response()]
        records += [self.task_notification("a"), self.final_response("update")]
        self.assertEqual(r.parse_claude(records)[1:3], ("running", "Waiting for background task"))
        records += [self.task_notification("b")]
        self.assertEqual(r.parse_claude(records)[1], "running", "Child completion alone is not parent delivery")
        records += [self.final_response("delivered", "Built and verified.")]
        self.assertEqual(r.parse_claude(records)[1:4], ("ready", "Response ready", "Built and verified."))
        self.assertEqual(len(r.parse_claude(records)[0]), 1)
        self.assertEqual(r.parse_claude(records + [self.task_notification("b")])[1], "ready", "Duplicate notifications must not reactivate a finished conversation")

    def test_claude_background_failure_and_question_need_attention(self):
        for terminal in ("failed", "stopped", "killed", "cancelled"):
            records = [self.user("request", "Build it"), self.async_agent("a"), self.final_response(), self.task_notification("a", terminal)]
            self.assertEqual(r.parse_claude(records)[1], "needsMe")
            self.assertEqual(r.parse_claude(records + [self.final_response("handled", "I have handled it.")])[1], "ready")
        question = {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "AskUserQuestion"}]}}
        self.assertEqual(r.parse_claude([self.async_agent("a"), question])[1:3], ("needsMe", "Question"))

    def test_claude_task_output_can_finish_pending_agent(self):
        records = [self.async_agent("a"), self.final_response()]
        result = self.user("result", [{"type": "tool_result", "tool_use_id": "wait"}], toolUseResult={"task": {"task_id": "a", "status": "completed"}})
        self.assertEqual(r.parse_claude(records + [result])[1], "running")
        self.assertEqual(r.parse_claude(records + [result, self.final_response("delivered", "Done")])[1], "ready")

    def test_claude_background_shell_outlasts_progress_without_task_output(self):
        records = [self.user("request", "Rebuild and test both versions"), self.async_shell("tests"), self.final_response(text="Both rebuilt; the suites are still running.")]
        parsed = r.parse_claude(records)
        self.assertEqual(parsed[1:4], ("running", "Waiting for background task", ""))
        self.assertEqual([x["id"] for x in parsed[0]], ["request"])
        self.assertNotIn("Private", json.dumps(parsed))
        self.assertNotIn("/private/project", json.dumps(parsed))
        with patch.object(r.time, "time", return_value=parsed[4] + 30 * 60):
            self.assertEqual(r.base_card("claude", "tests", "Tests", "", 100, parsed, "")["state"], "running")
        records.append(self.task_notification("tests"))
        self.assertEqual(r.parse_claude(records)[1], "running")
        records.append(self.final_response("delivered", "Both test suites passed."))
        self.assertEqual(r.parse_claude(records)[1:4], ("ready", "Response ready", "Both test suites passed."))

    def test_claude_waits_for_shell_and_agent_and_handles_shell_failure(self):
        records = [self.user("request", "Build and test"), self.async_agent("builder"), self.async_shell("tests"), self.final_response()]
        records += [self.task_notification("builder"), self.final_response("builder-update")]
        self.assertEqual(r.parse_claude(records)[1], "running", "Finishing the agent must not hide pending shell work")
        result = self.user("result", [{"type": "tool_result", "tool_use_id": "wait"}], toolUseResult={"task": {"task_id": "tests", "status": "completed"}})
        self.assertEqual(r.parse_claude(records + [result, self.final_response("done", "Verified.")])[1], "ready")
        for status in ("failed", "stopped", "killed", "cancelled"):
            self.assertEqual(r.parse_claude(records + [self.task_notification("tests", status)])[1], "needsMe")

    def test_claude_foreground_shell_does_not_leave_a_pending_task(self):
        foreground = self.async_shell("foreground")
        del foreground["toolUseResult"]["backgroundTaskId"]
        self.assertEqual(r.parse_claude([foreground, self.final_response("done", "Tests passed.")])[1], "ready")

    def test_claude_ordinary_xml_cannot_complete_agent_or_shell_task(self):
        fake = self.task_notification("a"); fake.pop("origin")
        for launch in (self.async_agent("a"), self.async_shell("a")):
            self.assertEqual(r.parse_claude([launch, fake, self.final_response()])[1], "running")

    def test_claude_keeps_identical_real_submissions_but_not_replays_or_tools(self):
        a = self.user("a", "Yes, go ahead")
        records = [a, a, self.user("b", "Yes, go ahead"), self.user("tool", [{"type": "tool_result", "content": "done"}]), self.user("meta", "Injected context", isMeta=True)]
        requests = r.parse_claude(records)[0]
        self.assertEqual([x["id"] for x in requests], ["a", "b"])

    def test_claude_completion_requires_final_text_not_thinking(self):
        start = self.user("a", "Build it")
        thinking = {"type": "assistant", "uuid": "b", "message": {"stop_reason": "end_turn", "content": [{"type": "thinking", "thinking": "private"}]}}
        self.assertEqual(r.parse_claude([start, thinking])[1], "running")
        final = {"type": "assistant", "uuid": "c", "message": {"stop_reason": "end_turn", "content": [{"type": "text", "text": "Built it."}]}}
        self.assertEqual(r.parse_claude([start, thinking, final])[1], "ready")
        self.assertNotIn("private", json.dumps(r.parse_claude([start, thinking, final])))

    def test_claude_question_and_error(self):
        question = {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "AskUserQuestion"}]}}
        self.assertEqual(r.parse_claude([question])[1], "needsMe")
        failure = {"type": "assistant", "isApiErrorMessage": True, "message": {"content": [{"type": "text", "text": "Error"}]}}
        self.assertEqual(r.parse_claude([failure])[1], "needsMe")

    def test_claude_task_notifications_are_not_user_requests(self):
        original = self.user("real", "Check the labels")
        transport = self.user("notification", "<task-notification>Worker finished</task-notification>")
        self.assertEqual([x["id"] for x in r.parse_claude([original, transport])[0]], ["real"])

    def test_one_bad_codex_history_does_not_hide_other_conversations(self):
        with tempfile.TemporaryDirectory() as d, patch.object(r, "HOME", Path(d)):
            root = Path(d) / ".codex"; root.mkdir()
            rollout = root / "working.jsonl"
            rollout.write_text(json.dumps({"type": "event_msg", "payload": {"type": "task_complete", "last_agent_message": "Done"}}) + "\n")
            with sqlite3.connect(root / "state_5.sqlite") as con:
                con.execute("CREATE TABLE threads (id TEXT,name TEXT,title TEXT,cwd TEXT,updated_at INTEGER,history_mode TEXT,rollout_path TEXT,source TEXT,thread_source TEXT)")
                con.executemany("INSERT INTO threads VALUES (?,?,?,?,?,?,?,?,?)", [("broken", "Broken", "Broken", "/one", 100, "paginated", "", "vscode", "user"), ("working", "Working", "Working", "/two", 100, "rollout", str(rollout), "vscode", "user")])
            with sqlite3.connect(root / "thread_history_1.sqlite") as con:
                con.execute("CREATE TABLE thread_items (thread_id TEXT,item_id TEXT,created_at_ms INTEGER,item_json TEXT,item_type TEXT,rollout_ordinal INTEGER)")
                con.execute("INSERT INTO thread_items VALUES ('broken','item',100000,'malformed','userMessage',1)")
            cards = {c["nativeID"]: c for c in r.codex_cards(0)}
            self.assertEqual(set(cards), {"broken", "working"})
            self.assertEqual(cards["broken"]["state"], "unknown")
            self.assertEqual(cards["working"]["state"], "ready")
            (root / "thread_history_1.sqlite").unlink()
            self.assertEqual(len(r.codex_cards(0)), 2)

    def test_codex_transport_duplicate_is_not_request(self):
        records = [{"type": "event_msg", "payload": {"type": "user_message", "message": "Build it"}}, {"type": "response_item", "payload": {"type": "message", "id": "a", "role": "user", "content": [{"type": "input_text", "text": "Build it"}]}}, {"type": "response_item", "payload": {"type": "message", "id": "env", "role": "user", "content": [{"type": "input_text", "text": "<environment_context>private metadata</environment_context>"}]}}, {"type": "event_msg", "payload": {"type": "task_complete", "last_agent_message": "Built it"}}]
        result = r.parse_codex_legacy(records)
        self.assertEqual(len(result[0]), 1)
        self.assertEqual(result[1], "ready")

    def test_codex_ambient_browser_context_does_not_replace_user_request(self):
        context = '<in-app-browser-context source="ambient-ui-state">Injected page state</in-app-browser-context>'
        def message(key, text):
            return {"type": "response_item", "payload": {"type": "message", "id": key, "role": "user", "content": [{"type": "input_text", "text": text}]}}
        result = r.parse_codex_legacy([message("real", "Review the layout"), message("ambient", context), message("combined", context + "\nFix the sidebar")])[0]
        self.assertEqual([x["text"] for x in result], ["Review the layout", "Fix the sidebar"])

    def test_incomplete_log_tail_recovers_without_duplicates(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "session.jsonl"
            p.write_text(json.dumps(self.user("a", "First")) + '\n{"type":')
            self.assertEqual(len(r.read_jsonl(p, r.parse_claude)[0]), 1)
            p.write_text(json.dumps(self.user("a", "First")) + "\n" + json.dumps(self.user("b", "Second")) + "\n")
            self.assertEqual(len(r.read_jsonl(p, r.parse_claude)[0]), 2)

    def test_stale_running_is_unknown_not_completed(self):
        result = r.base_card("codex", "a", "Title", "", 100, ([], "running", "", "", 100, "turn"), "codex://threads/a")
        self.assertEqual(result["state"], "unknown")

    def test_readonly_database_cannot_write(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "source.sqlite"
            with sqlite3.connect(p) as con:
                con.execute("CREATE TABLE example (id TEXT)")
            with r.readonly(p) as con:
                with self.assertRaises(sqlite3.OperationalError):
                    con.execute("INSERT INTO example VALUES ('bad')")


if __name__ == "__main__":
    unittest.main()

class ReleaseReaderTests(unittest.TestCase):
    def test_disabled_provider_never_reads_its_store(self):
        with patch.object(r, "DISABLED_PROVIDERS", {"claude"}), patch.object(r, "claude_cards") as claude, patch.object(r, "codex_cards", return_value=[]):
            result = r.scan()
        claude.assert_not_called()
        self.assertEqual(result["health"]["claude"], "Disabled")
        self.assertTrue(result["health"]["codex"].startswith("Connected"))

    def test_schema_detection_does_not_write_database(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "source.sqlite"
            con = sqlite3.connect(path); con.execute("CREATE TABLE threads (id TEXT)"); con.close()
            before = path.read_bytes()
            con = r.readonly(path)
            with self.assertRaises(r.UnsupportedFormat):
                r.require_columns(con, "threads", ["id", "history_mode"])
            con.close()
            self.assertEqual(path.read_bytes(), before)

    def test_access_denial_has_safe_specific_status(self):
        with patch.object(r, "claude_cards", side_effect=PermissionError(13, "secret path")), patch.object(r, "codex_cards", return_value=[]):
            result = r.scan()
        self.assertEqual(result["health"]["claude"], "Access denied")
        self.assertNotIn("secret", json.dumps(result))

    def test_custom_roots_and_no_installed_apps(self):
        with tempfile.TemporaryDirectory() as temp, patch.object(r, "HOME", Path(temp)), patch.object(r, "CODEX_HOME", Path(temp)/"custom-codex"), patch.object(r, "CLAUDE_HOME", Path(temp)/"custom-claude"):
            self.assertEqual(r.codex_root(), Path(temp)/"custom-codex")
            self.assertEqual(r.claude_root(), Path(temp)/"custom-claude")
            with patch.object(r, "claude_cards", side_effect=FileNotFoundError()), patch.object(r, "codex_cards", return_value=[]), patch.object(Path, "exists", return_value=False):
                self.assertEqual(r.scan()["health"]["claude"], "Not installed")
