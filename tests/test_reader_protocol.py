"""Synthetic contract and failure tests. No native stores or API credentials."""
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parents[1] / "Resources"))
from kanbanana_reader import adapters, jsonl, worker
from kanbanana_reader.parsers import parse_claude, parse_codex_legacy


def user(key, text="Build an example"):
    return {"type": "user", "uuid": key, "timestamp": 100, "message": {"content": text}}


class ReaderProtocolTests(unittest.TestCase):
    def setUp(self):
        jsonl.CACHE.clear()
        adapters.PAGINATED_CACHE.clear()

    def test_python_encoder_matches_swift_golden_fixture(self):
        path = Path(__file__).parent / "KanbananaServicesTests/Fixtures/provider-frame-v1.json"
        golden = json.loads(path.read_text())
        card = {**golden["cards"][0], "provider": "claude", "response": golden["cards"][0]["response"]}
        card["requests"] = [{"id": "request-1", "text": "Build it", "time": 90}] + card["requests"]
        result = {**golden, "cards": [card], "inventoryComplete": True}
        encoder = worker.DeltaEncoder("claude")
        frames = list(encoder.frames(result))
        self.assertEqual(frames[0], golden)
        self.assertTrue(frames[1]["inventoryComplete"])
        self.assertEqual(frames[1]["cards"], [])
        steady = list(encoder.frames(result))
        self.assertEqual(len(steady), 1)
        self.assertEqual(frames[0]["cards"][0]["response"], "Added labels; tests were not run.")
        self.assertNotIn("Build it", json.dumps(frames))

    def test_history_pages_are_bounded_ordered_and_nonoverlapping(self):
        requests = [{"id": str(i), "text": "Example", "time": i} for i in range(123)]
        with patch.object(adapters, "scan_provider", return_value={"cards": [{"id": "claude:x", "requests": requests}]}):
            newest = worker.history_page("claude", "claude:x", None)
            middle = worker.history_page("claude", "claude:x", newest["requests"][0]["id"])
            oldest = worker.history_page("claude", "claude:x", middle["requests"][0]["id"])
            self.assertEqual([len(page["requests"]) for page in [oldest, middle, newest]], [23, 50, 50])
            self.assertEqual(oldest["requests"] + middle["requests"] + newest["requests"], requests)
            self.assertFalse(oldest["hasMore"])
            with self.assertRaises(ValueError):
                worker.history_page("claude", "claude:x", "removed")

    def test_latest_report_is_bounded_and_changes_emit_a_delta(self):
        golden = json.loads((Path(__file__).parent / "KanbananaServicesTests/Fixtures/provider-frame-v1.json").read_text())
        card = golden["cards"][0]
        card["response"] = "x" * 25000
        encoder = worker.DeltaEncoder("claude")
        self.assertEqual(len(list(encoder.frames(golden))[0]["cards"][0]["response"]), 20000)
        card["response"] = "Corrected the result."
        self.assertEqual(list(encoder.frames(golden))[0]["cards"][0]["response"], card["response"])
        card["state"] = "running"
        self.assertEqual(list(encoder.frames(golden))[0]["cards"][0]["response"], "")

    def test_questions_become_reports_and_new_requests_clear_them(self):
        args = {"questions": [{"question": "Which repository should I use?", "options": [{"label": "Example"}]}]}
        claude = {"type": "assistant", "uuid": "q", "timestamp": 100, "message": {"content": [
            {"type": "tool_use", "name": "AskUserQuestion", "input": args}]}}
        codex = {"type": "response_item", "timestamp": 100, "payload": {"type": "function_call",
            "name": "functions.request_user_input", "call_id": "q", "arguments": json.dumps(args)}}
        for report in [parse_claude([claude]), parse_codex_legacy([codex])]:
            self.assertEqual(report[1], "needsMe")
            self.assertIn("Which repository", report[3])
            self.assertIn("Example", report[3])
        self.assertEqual(parse_claude([claude, user("next")])[3], "")
        answer = {"type": "response_item", "timestamp": 101, "payload": {"type": "function_call_output", "call_id": "q"}}
        self.assertEqual(parse_codex_legacy([codex, answer])[3], "")

    def test_paginated_report_cannot_come_from_an_older_turn(self):
        with sqlite3.connect(":memory:") as con:
            con.row_factory = sqlite3.Row
            con.execute("CREATE TABLE thread_turns(thread_id,turn_id,status,started_at,completed_at,rollout_ordinal)")
            con.execute("CREATE TABLE thread_items(thread_id,turn_id,item_id,created_at_ms,item_json,item_type,rollout_ordinal)")
            con.execute("INSERT INTO thread_turns VALUES('x','old','completed',1,2,1)")
            con.execute("INSERT INTO thread_items VALUES('x','old','final',2,?,'agentMessage',1)",
                        (json.dumps({"type": "agentMessage", "phase": "final_answer", "text": "Old success"}),))
            con.execute("INSERT INTO thread_turns VALUES('x','new','failed',3,4,2)")
            self.assertEqual(adapters.codex_paginated(con, "x")[1:4], ("needsMe", "Agent error", ""))
            con.execute("UPDATE thread_turns SET status='inProgress' WHERE turn_id='new'")
            tool = {"type": "dynamicToolCall", "tool": "request_user_input", "status": "inProgress",
                    "arguments": {"questions": [{"question": "Which file?"}]}}
            con.execute("INSERT INTO thread_items VALUES('x','new','question',4,?,'dynamicToolCall',2)", (json.dumps(tool),))
            self.assertEqual(adapters.codex_paginated(con, "x")[1:4], ("needsMe", "Question", "Which file?"))

    def test_paginated_failure_shows_capacity_message_until_next_turn(self):
        with sqlite3.connect(":memory:") as con:
            con.row_factory = sqlite3.Row
            con.execute("CREATE TABLE thread_turns(thread_id,turn_id,status,started_at,completed_at,rollout_ordinal,error_json)")
            con.execute("CREATE TABLE thread_items(thread_id,turn_id,item_id,created_at_ms,item_json,item_type,rollout_ordinal)")
            error = {"message": "Selected model is at capacity. Please try a different model.",
                     "codexErrorInfo": "serverOverloaded"}
            con.execute("INSERT INTO thread_turns VALUES('x','failed','failed',1,2,1,?)", (json.dumps(error),))
            # Even a final-looking message earlier in the failed turn must not
            # take precedence over its terminal error.
            con.execute("INSERT INTO thread_items VALUES('x','failed','partial',1,?,'agentMessage',1)",
                        (json.dumps({"type": "agentMessage", "phase": "final_answer", "text": "Partial progress"}),))
            self.assertEqual(adapters.codex_paginated(con, "x")[1:4],
                             ("needsMe", "Model at capacity", error["message"]))
            con.execute("INSERT INTO thread_turns VALUES('x','retry','inProgress',3,NULL,2,NULL)")
            self.assertEqual(adapters.codex_paginated(con, "x")[1:4], ("running", "", ""))
            con.execute("UPDATE thread_turns SET status='completed',completed_at=4 WHERE turn_id='retry'")
            con.execute("INSERT INTO thread_items VALUES('x','retry','final',4,?,'agentMessage',2)",
                        (json.dumps({"type": "agentMessage", "phase": "final_answer", "text": "Finished"}),))
            self.assertEqual(adapters.codex_paginated(con, "x")[1:4], ("ready", "Response ready", "Finished"))

    def test_paginated_optional_error_is_defensive_and_bounded(self):
        with sqlite3.connect(":memory:") as con:
            con.row_factory = sqlite3.Row
            con.execute("CREATE TABLE thread_turns(thread_id,turn_id,status,started_at,completed_at,rollout_ordinal,error_json)")
            con.execute("CREATE TABLE thread_items(thread_id,turn_id,item_id,created_at_ms,item_json,item_type,rollout_ordinal)")
            con.execute("INSERT INTO thread_turns VALUES('x','failed','failed',1,2,1,NULL)")
            for value in [None, '{', 'null', '[]', '42', '{"message":42}']:
                con.execute("UPDATE thread_turns SET error_json=?", (value,))
                self.assertEqual(adapters.codex_paginated(con, "x")[1:4], ("needsMe", "Agent error", ""))
            con.execute("UPDATE thread_turns SET error_json=?", (json.dumps({"message": "x" * 25000}),))
            self.assertEqual(adapters.codex_paginated(con, "x")[1:4], ("needsMe", "Agent error", "x" * 20000))

    def test_continued_codex_history_keeps_card_identity_and_reads_active_segment(self):
        tid, segment = "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222"
        with tempfile.TemporaryDirectory() as directory, patch.object(adapters, "CODEX_HOME", Path(directory)):
            root = Path(directory)
            path = root / f"rollout-2026-10-29T10-00-00-{tid}_{segment}.jsonl"
            path.write_text(json.dumps({"type": "session_meta", "payload": {"id": tid,
                "history_base": {"thread_id": tid, "end_ordinal_exclusive": 10}}}) + "\n")
            with sqlite3.connect(root / "state_5.sqlite") as state:
                state.execute("CREATE TABLE threads(id,name,title,cwd,updated_at,history_mode,rollout_path,source,thread_source)")
                state.execute("INSERT INTO threads VALUES(?,?,?,?,?,?,?,?,?)", (tid,"Example","Example","/example",100,"paginated",str(path),"vscode","user"))
            with sqlite3.connect(root / "thread_history_1.sqlite") as con:
                con.row_factory = sqlite3.Row
                con.execute("CREATE TABLE thread_turns(thread_id,turn_id,status,started_at,completed_at,rollout_ordinal)")
                con.execute("CREATE TABLE thread_items(thread_id,turn_id,item_id,created_at_ms,item_json,item_type,rollout_ordinal)")
                con.execute("INSERT INTO thread_turns VALUES(?,'old','interrupted',1,2,10)", (tid,))
                for thread, key, ordinal in [(tid, "inherited", 1), (tid, "discarded", 10), (segment, "current", 11)]:
                    con.execute("INSERT INTO thread_items VALUES(?,'turn',?,1000,?,'userMessage',?)", (thread,key,json.dumps({"type":"userMessage","content":key}),ordinal))
                # Do not present the old interruption as current while the new
                # segment's projection is temporarily missing.
                self.assertEqual(adapters.codex_paginated(con, tid, rollout_path=path)[1:3], ("unknown", "History temporarily unavailable"))
                con.execute("INSERT INTO thread_turns VALUES(?,'new','inProgress',3,NULL,11)", (segment,))
                con.commit()
                with patch.object(adapters.time, "time", return_value=4):
                    card = adapters.codex_cards(0)[0]
                self.assertEqual(card["id"], "codex:" + tid)
                self.assertEqual(card["url"], "codex://threads/" + tid)
                self.assertEqual(card["state"], "running")
                self.assertEqual([r["id"] for r in card["requests"]], ["inherited", "current"])
                question = {"tool":"request_user_input","status":"inProgress","arguments":{"questions":[{"question":"Which file?"}]}}
                con.execute("INSERT INTO thread_items VALUES(?,'new','q',4000,?,'dynamicToolCall',12)", (segment,json.dumps(question)))
                self.assertEqual(adapters.codex_paginated(con,tid,rollout_path=path)[1:4], ("needsMe","Question","Which file?"))
                con.execute("UPDATE thread_turns SET status='completed',completed_at=5 WHERE thread_id=?", (segment,))
                con.execute("INSERT INTO thread_items VALUES(?,'new','final',5000,?,'agentMessage',13)", (segment,json.dumps({"type":"agentMessage","phase":"final_answer","text":"Finished the example."})))
                con.commit()
                card = adapters.codex_cards(0)[0]
                self.assertEqual((card["state"],card["response"],card["eventID"]), ("ready","Finished the example.","new:completed"))

    def test_continuation_metadata_must_match_the_conversation(self):
        tid, segment = "11111111-1111-4111-8111-111111111111", "22222222-2222-4222-8222-222222222222"
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / f"rollout-2026-10-29T10-00-00-{tid}_{segment}.jsonl"
            invalid = [[], {"type":"session_meta","payload":None},
                       {"type":"session_meta","payload":{"id":tid,"history_base":None}},
                       {"type":"session_meta","payload":{"id":segment,"history_base":{"thread_id":tid,"end_ordinal_exclusive":10}}},
                       {"type":"session_meta","payload":{"id":tid,"history_base":{"thread_id":segment,"end_ordinal_exclusive":10}}}]
            for record in invalid:
                path.write_text(json.dumps(record) + "\n")
                with self.assertRaises(adapters.UnsupportedFormat):
                    adapters.codex_history_segment(tid, path)
            self.assertEqual(adapters.codex_history_segment(tid, None), (tid,None))

    def test_append_decodes_only_new_records_and_unchanged_decodes_none(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "history.jsonl"
            path.write_text(json.dumps(user("one")) + "\n")
            with patch.object(jsonl.json, "loads", wraps=json.loads) as decode:
                self.assertEqual(len(jsonl.read_jsonl(path, parse_claude)[0]), 1)
                self.assertEqual(decode.call_count, 1)
                jsonl.read_jsonl(path, parse_claude)
                self.assertEqual(decode.call_count, 1)
                with path.open("a") as stream:
                    stream.write(json.dumps(user("two")) + "\n")
                self.assertEqual(len(jsonl.read_jsonl(path, parse_claude)[0]), 2)
                self.assertEqual(decode.call_count, 2)

    def test_rewrite_rotation_and_partial_tail_do_not_duplicate_or_lose_requests(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "history.jsonl"
            path.write_text(json.dumps(user("old")) + "\n")
            jsonl.read_jsonl(path, parse_claude)
            # Same inode, larger file, modified prefix: cannot assume append-only.
            path.write_text(json.dumps(user("edited", "Different request")) + "\n" + json.dumps(user("second")))
            self.assertEqual([r["id"] for r in jsonl.read_jsonl(path, parse_claude)[0]], ["edited"])
            with path.open("a") as stream:
                stream.write("\n")
            self.assertEqual([r["id"] for r in jsonl.read_jsonl(path, parse_claude)[0]], ["edited", "second"])
            replacement = path.with_suffix(".new")
            replacement.write_text(json.dumps(user("rotated")) + "\n")
            replacement.replace(path)
            self.assertEqual([r["id"] for r in jsonl.read_jsonl(path, parse_claude)[0]], ["rotated"])

    def test_completed_malformed_record_is_a_read_failure_not_silent_success(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "history.jsonl"
            path.write_text(json.dumps(user("one")) + "\ninvalid\n")
            with self.assertRaises(ValueError):
                jsonl.read_jsonl(path, parse_claude)
            self.assertNotIn(str(path), jsonl.CACHE)

    def test_transcript_cache_evicts_oldest_entries(self):
        with tempfile.TemporaryDirectory() as root, patch.object(jsonl, "CACHE_LIMIT", 3):
            for i in range(5):
                path = Path(root) / f"{i}.jsonl"
                path.write_text(json.dumps(user(str(i))) + "\n")
                jsonl.read_jsonl(path, parse_claude)
            self.assertEqual([Path(key).name for key in jsonl.CACHE], ["2.jsonl", "3.jsonl", "4.jsonl"])

    def test_bad_claude_metadata_and_denied_subdirectory_are_partial(self):
        with tempfile.TemporaryDirectory() as root, patch.object(adapters, "HOME", Path(root)), patch.object(adapters, "PATHS", {}), patch.object(adapters, "PATHS_AT", float("inf")):
            folder = Path(root) / "Library/Application Support/Claude/claude-code-sessions"
            folder.mkdir(parents=True)
            (folder / "bad.json").write_text("malformed")
            scan = adapters.scan_provider("claude")
            self.assertEqual(scan["health"]["status"], "partial")
            self.assertFalse(scan["inventoryComplete"])
            def denied(*args, **kwargs):
                kwargs["onerror"](PermissionError(13, "private-path"))
                return iter([])
            with patch.object(adapters.os, "walk", side_effect=denied):
                scan = adapters.scan_provider("claude")
            self.assertEqual(scan["health"], {"status": "partial", "issue": "Access denied"})
            self.assertFalse(scan["inventoryComplete"])
            self.assertNotIn("private-path", json.dumps(scan))

    def test_unchanged_paginated_history_is_not_redecoded(self):
        with sqlite3.connect(":memory:") as con:
            con.row_factory = sqlite3.Row
            con.execute("CREATE TABLE thread_turns(thread_id,turn_id,status,started_at,completed_at,rollout_ordinal)")
            con.execute("CREATE TABLE thread_items(thread_id,turn_id,item_id,created_at_ms,item_json,item_type,rollout_ordinal)")
            con.execute("INSERT INTO thread_turns VALUES('x','turn','completed',1,2,1)")
            for i in range(200):
                con.execute("INSERT INTO thread_items VALUES('x','turn',?,1,?,'userMessage',?)", (str(i), json.dumps({"type": "userMessage", "content": "x" * 2000}), i))
            with patch.object(adapters.json, "loads", wraps=json.loads) as decode:
                first = adapters.codex_paginated(con, "x", generation="one")
                self.assertEqual(decode.call_count, 200)
                self.assertEqual(adapters.codex_paginated(con, "x", generation="one"), first)
                self.assertEqual(decode.call_count, 200)
                adapters.codex_paginated(con, "x", generation="two")
                self.assertEqual(decode.call_count, 400)


if __name__ == "__main__":
    unittest.main()
