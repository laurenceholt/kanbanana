"""Limited, read-only discovery from the desktop app's ChatGPT catalog.

This is metadata, not a message store. Absence and a null async status never
prove deletion or completion. No cookies, credentials, or network APIs are used.
"""
import time
import uuid
from contextlib import closing


def cards(cutoff, tracked_ids=()):
    from . import adapters as a
    result = a.SourceBatch()
    # A locally cached catalog is not an authoritative cloud inventory.
    result.inventory_complete = False
    now = time.time()
    with closing(a.readonly(a.codex_root() / "sqlite/codex.db")) as con:
        con.execute("BEGIN")
        a.require_columns(con, "local_thread_catalog", ["host_id", "thread_id", "display_title",
            "source_kind", "source_updated_at", "missing_candidate", "chatgpt_async_status"])
        active = {}
        tables = {r[0] for r in con.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        if "active_chat_turns" in tables:
            a.require_columns(con, "active_chat_turns", ["account_id", "user_id", "thread_id", "observed_at_ms"])
            for row in con.execute("SELECT account_id,user_id,thread_id,observed_at_ms FROM active_chat_turns"):
                host = "chatgpt:" + row["account_id"] + ":" + row["user_id"]
                active[(host, row["thread_id"])] = max(active.get((host, row["thread_id"]), 0), row["observed_at_ms"] / 1000)
        seen = set()
        for row in con.execute("SELECT * FROM local_thread_catalog WHERE source_kind='chatgpt' AND missing_candidate=0 ORDER BY source_updated_at DESC"):
            native_id = row["thread_id"]
            try:
                if str(uuid.UUID(native_id)) != native_id.lower():
                    continue
            except (ValueError, TypeError, AttributeError):
                continue
            updated = a.stamp(row["source_updated_at"])
            if native_id in seen or (updated < cutoff and "chatgpt:" + native_id not in tracked_ids):
                continue
            seen.add(native_id)
            state, reason = "unknown", "ChatGPT has not exposed a completion status"
            heartbeat = active.get((row["host_id"], native_id), 0)
            # Values verified against the desktop async-status enum: streaming=3,
            # unread=4, realtime=5, realtime_busy=6. Other values stay unknown.
            status = row["chatgpt_async_status"]
            if 0 <= now - heartbeat <= 30:
                state, reason = "running", "ChatGPT reports an active turn"
            elif heartbeat > updated:
                reason = "ChatGPT activity ended without a current completion signal"
            elif status == 4:
                state, reason = "ready", "ChatGPT reports an unread result"
            elif status in (3, 5, 6) and 0 <= now - updated <= 120:
                state, reason = "running", "ChatGPT reports an active turn"
            elif status in (3, 5, 6):
                reason = "ChatGPT activity signal is old; completion is unknown"
            # Heartbeats must not change the revision or invalidate curation.
            card = a.base_card("chatgpt", native_id, row["display_title"], "", updated,
                ([], "unknown", reason, "", updated, "catalog:" + str(updated)),
                "https://chatgpt.com/c/" + native_id)
            card["state"] = state
            result.append(card)
    return result
