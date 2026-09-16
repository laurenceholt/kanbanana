# Changelog

## Unreleased

- Add the banana mark and kanbanana title to Focus mode without taking space from the card list.
- Apply pipe backpressure during startup bursts so a busy interface cannot drop reader updates or misreport a size-limit failure.

## 0.3.0-beta.1

- Separate Core, Services and macOS app targets; Swift 6 concurrency checking.
- Independent provider workers, continuous freshness deadlines, bounded framing and orderly restart/shutdown.
- Typed partial observations preserve last known evidence through unreadable histories.
- Incremental JSONL parsing, cached SQLite results, changed-card updates and paged request history.
- Backed-up v1 migration separates durable notes/choices from recoverable observations and the daily usage ledger.
- Async repository writes, restore revision protection and cancellable summary scheduling.
- Synthetic `--demo` mode, shared Python/Swift protocol fixture, fault tests and documented source-only installation.

Source-only release; no paid developer membership is needed for a local build. Installed v2 documents require 0.3; portable exports remain v1. See recovery guidance before downgrading.

## 0.2.0-beta.1

First public source beta.

- Three board views: Focus, Projects and Columns; five workflow states, priorities, notes and recoverable parking.
- Direct summaries, opt-in cloud processing, project exclusions, daily attempt limits and Keychain deletion.
- Onboarding, provider switches, custom source locations, schema checks and clearer health messages.
- Rolling backups, validated export/restore and diagnostics that omit conversation content.
- A banana mark and more compact menu-bar counts; existing interface logo dimensions retained.
- Bundled, pinned Python runtime; local build and Developer ID/notarization scripts.
- MIT license, provenance notices, privacy/recovery documentation, synthetic previews and automated checks.

Native permission detection, older provider versions and remote-only coverage remain limited. See docs/COMPATIBILITY.md. This source release does not include a notarized download.
