"""Process entry point and newline-delimited protocol v1. One provider per worker."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import time
from . import adapters


class DeltaEncoder:
    def __init__(self, provider):
        self.provider = provider
        self.signatures = {}

    def frames(self, result):
        common = {"protocolVersion": 1, "provider": self.provider,
                  "health": result["health"], "knownIDs": result["knownIDs"],
                  "scannedAt": result["scannedAt"]}
        current = {}
        for card in result["cards"]:
            # Live monitoring needs only the latest request. History is paged on
            # demand. Include only the bounded latest report for card summaries.
            observation = {key: value for key, value in card.items() if key != "provider"}
            observation["requests"] = card["requests"][-1:]
            observation["response"] = card.get("response", "")[-20000:] if card["state"] in ("ready", "needsMe") else ""
            signature = hashlib.sha256(json.dumps(observation, sort_keys=True).encode()).digest()
            current[card["id"]] = signature
            if self.signatures.get(card["id"]) != signature:
                yield {**common, "cards": [observation], "inventoryComplete": False}
        self.signatures = current
        # An empty delta still renews freshness. Only a complete inventory can
        # establish absence, independently of which cards changed.
        yield {**common, "cards": [], "inventoryComplete": result["inventoryComplete"]}


def history_page(provider, card_id, before):
    if not provider or not card_id.startswith(provider + ":"):
        raise ValueError("Mismatched provider")
    result = adapters.scan_provider(provider, 0, {card_id})
    card = next((card for card in result["cards"] if card["id"] == card_id), None)
    if card is None or card.get("observationIssue"):
        raise ValueError("History unavailable")
    requests = card["requests"]
    end = len(requests)
    if before:
        end = next((i for i, request in enumerate(requests) if request["id"] == before), -1)
        if end < 0:
            raise ValueError("History changed; reload the latest page")
    start = max(0, end - 50)
    return {"protocolVersion": 1, "cardID": card_id, "requests": requests[start:end], "hasMore": start > 0}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--watch", action="store_true")
    parser.add_argument("--days", type=int, default=14)
    parser.add_argument("--parent-pid", type=int)
    parser.add_argument("--tracked-id", action="append", default=[])
    parser.add_argument("--health-log")
    parser.add_argument("--provider", choices=["claude", "codex"])
    parser.add_argument("--disable-provider", choices=["claude", "codex"], action="append", default=[])
    parser.add_argument("--codex-home", type=Path)
    parser.add_argument("--claude-home", type=Path)
    parser.add_argument("--history-id")
    parser.add_argument("--before-request")
    args = parser.parse_args()
    adapters.DISABLED_PROVIDERS = set(args.disable_provider)
    adapters.CODEX_HOME = args.codex_home
    adapters.CLAUDE_HOME = args.claude_home
    if args.history_id:
        try:
            print(json.dumps(history_page(args.provider, args.history_id, args.before_request), ensure_ascii=False), flush=True)
            return 0
        except (ValueError, OSError):
            return 1
    tracked = set(args.tracked_id)
    delta = DeltaEncoder(args.provider) if args.provider else None
    health_log = adapters.HealthLog(args.health_log) if args.health_log else None
    while True:
        if args.parent_pid and os.getppid() != args.parent_pid:
            return 0
        if delta:
            result = adapters.scan_provider(args.provider, args.days, tracked)
            tracked.update(result["knownIDs"])
            for frame in delta.frames(result):
                print(json.dumps(frame, ensure_ascii=False), flush=True)
            active = any(card["state"] == "running" for card in result["cards"])
        else:
            result = adapters.scan(args.days, tracked)
            tracked.update(card["id"] for card in result["cards"])
            if health_log:
                health_log.record(result)
            print(json.dumps(result, ensure_ascii=False), flush=True)
            active = True
        if not args.watch:
            return 0
        time.sleep(4 if active else 10)
