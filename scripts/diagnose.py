"""Print aggregate integration health without exporting conversation content."""
import importlib.util
from pathlib import Path
import time

spec = importlib.util.spec_from_file_location("reader", Path(__file__).parents[1] / "Resources/reader.py")
reader = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reader)
for scan_number in (1, 2):
    start = time.monotonic()
    snapshot = reader.scan()
    print(f"Scan {scan_number}: {time.monotonic() - start:.3f}s")
    for provider in ("claude", "codex"):
        cards = [c for c in snapshot["cards"] if c["provider"] == provider]
        states = {s: sum(c["state"] == s for c in cards) for s in ("running", "needsMe", "ready", "unknown")}
        print(provider, snapshot["health"][provider], f"{sum(len(c['requests']) for c in cards)} requests", states)
