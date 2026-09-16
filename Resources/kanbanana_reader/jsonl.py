"""Incremental transcript parsing with bounded cache ownership and rotation checks."""
from collections import OrderedDict
import hashlib
import json
from pathlib import Path
from .parsers import ClaudeParser, CodexParser, parse_claude

CACHE = OrderedDict()
CACHE_LIMIT = 128


def read_jsonl(path, parser):
    if not path or not Path(path).is_file():
        return [], "unknown", "History unavailable", "", 0, ""
    path = Path(path)
    stat = path.stat()
    signature = (stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns)
    key = str(path)
    cached = CACHE.get(key)
    if cached and cached["signature"] == signature:
        CACHE.move_to_end(key)
        return cached["parser"].result()
    with path.open("rb") as stream:
        incremental = bool(cached and cached["signature"][:2] == signature[:2]
                           and stat.st_size > cached["signature"][2])
        # Validate all preceding bytes before applying a suffix. Compaction can
        # rewrite the middle while leaving inode, first/last bytes and size plausible.
        if incremental:
            prefix = hashlib.sha256()
            remaining = cached["offset"]
            while remaining:
                block = stream.read(min(65536, remaining))
                if not block:
                    incremental = False
                    break
                prefix.update(block)
                remaining -= len(block)
            incremental = incremental and prefix.digest() == cached["digest"]
        if incremental:
            state = cached["parser"]
            digest = prefix
        else:
            stream.seek(0)
            state = ClaudeParser() if parser is parse_claude else CodexParser()
            digest = hashlib.sha256()
        offset = stream.tell()
        while True:
            line = stream.readline()
            if not line or not line.endswith(b"\n"):
                break  # A partial streaming tail is retried when more bytes arrive.
            try:
                record = json.loads(line)
                if not isinstance(record, dict):
                    raise ValueError("History record is not an object")
                state.feed(record)
            except (ValueError, TypeError, AttributeError, KeyError):
                CACHE.pop(key, None)
                raise ValueError("History record could not be read") from None
            digest.update(line)
            offset = stream.tell()
    CACHE[key] = {"signature": signature, "offset": offset, "digest": digest.digest(), "parser": state}
    CACHE.move_to_end(key)
    while len(CACHE) > CACHE_LIMIT:
        CACHE.popitem(last=False)
    return state.result()
