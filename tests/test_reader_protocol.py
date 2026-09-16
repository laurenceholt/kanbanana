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
from kanbanana_reader.parsers import parse_claude


def user(key, text="Build an example"):
    return {"type": "user", "uuid": key, "timestamp": 100, "message": {"content": text}}


class ReaderProtocolTests(unittest.TestCase):
    def setUp(self):
        jsonl.CACHE.clear()
        adapters.PAGINATED_CACHE.clear()

    def test_python_encoder_matches_swift_golden_fixture(self):
        path = Path(__file__).parent / "KanbananaServicesTests/Fixtures/provider-frame-v1.json"
        golden = json.loads(path.read_text())
        card = {**golden["cards"][0], "provider": "claude", "response": "Assistant text stays out of IPC"}
        card["requests"] = [{"id": "request-1", "text": "Build it", "time": 90}] + card["requests"]
        result = {**golden, "cards": [card], "inventoryComplete": True}
        encoder = worker.DeltaEncoder("claude")
        frames = list(encoder.frames(result))
        self.assertEqual(frames[0], golden)
        self.assertTrue(frames[1]["inventoryComplete"])
        self.assertEqual(frames[1]["cards"], [])
        steady = list(encoder.frames(result))
        self.assertEqual(len(steady), 1)
        self.assertNotIn("Assistant text", json.dumps(frames))
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
