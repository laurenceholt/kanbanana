"""Reproducible synthetic reader workload; never opens native conversation stores."""
import argparse
import json
from pathlib import Path
import resource
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "Resources"))
from kanbanana_reader.jsonl import read_jsonl
from kanbanana_reader.parsers import parse_claude
from kanbanana_reader.worker import DeltaEncoder


def measure(operation, iterations=1):
    wall, cpu = time.perf_counter(), time.process_time()
    result = None
    for _ in range(iterations):
        result = operation()
    return result, {"wall_ms": round((time.perf_counter() - wall) * 1000 / iterations, 3),
                    "cpu_ms": round((time.process_time() - cpu) * 1000 / iterations, 3)}


def main():
    args = argparse.ArgumentParser()
    args.add_argument("--requests", type=int, default=5000)
    count = args.parse_args().requests
    if not 1 <= count <= 100000:
        raise SystemExit("Use between 1 and 100000 synthetic requests")
    def record(index):
        return json.dumps({"type": "user", "uuid": str(index), "timestamp": 100 + index,
                           "message": {"content": "Synthetic example. " + "x" * 2000}}) + "\n"
    with tempfile.TemporaryDirectory(prefix="kanbanana-benchmark-") as root:
        path = Path(root) / "history.jsonl"
        with path.open("w") as stream:
            for i in range(count):
                stream.write(record(i))
        parsed, cold = measure(lambda: read_jsonl(path, parse_claude))
        _, steady = measure(lambda: read_jsonl(path, parse_claude), 100)
        with path.open("a") as stream:
            stream.write(record(count))
        parsed, append = measure(lambda: read_jsonl(path, parse_claude))
        card = {"id": "claude:synthetic", "requests": parsed[0], "response": "Local only"}
        scan = {"cards": [card], "health": {"status": "connected"}, "knownIDs": [card["id"]],
                "scannedAt": 100, "inventoryComplete": True}
        delta = DeltaEncoder("claude")
        initial_bytes = sum(len(json.dumps(frame).encode()) for frame in delta.frames(scan))
        steady_bytes = sum(len(json.dumps(frame).encode()) for frame in delta.frames(scan))
        print(json.dumps({"requests": count + 1, "source_bytes": path.stat().st_size,
            "cold_parse": cold, "unchanged_scan_average_100": steady, "append_with_prefix_validation": append,
            "full_history_json_bytes": len(json.dumps(card).encode()), "first_delta_json_bytes": initial_bytes,
            "unchanged_delta_json_bytes": steady_bytes,
            "process_peak_rss_bytes_macos": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss}, indent=2))


if __name__ == "__main__":
    main()
