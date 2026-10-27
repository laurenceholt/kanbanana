# Changelog

## Unreleased

- Restore the visible native window title and standard Mac app activation (Dock and Command-Tab), retaining the menu-bar controls. Remove the custom content drag handle. Version `0.4.5`, build `9`; physical-click movement verification is pending.

- Make the banana/title a direct window move handle in Focus and full views, independent of native titlebar drag initiation. Keep first-click activation protection off that handle. Version `0.4.4`, build `8`.

- Give Focus and full views a native macOS titlebar outside the SwiftUI content; remove the simulated titlebar spacing. Explicitly keep native movement and resizing enabled. Version `0.4.3`, build `7`.

- Keep window move/resize events in AppKit: protect covered-window activation clicks with a content-only shield instead of swallowing mouse sequences in the window dispatcher. Use native content bounds to exclude the titlebar and resize edges. App version `0.4.2`, build `6`.

- Explain local-only discovery during onboarding and on an empty board, including work on another Mac. Distinguish scanning, disabled monitoring, unreadable sources, filtered results, empty statuses and parked work.
- Add Help in Focus and full views, an illustrated user guide, and optional summary setup with a fictional example, API/billing links and explicit opt-in. Prepare app version `0.4.1`, build `5`.

## 0.4.0-beta.1 (release candidate)

- Prepare Developer ID signing and notarized ZIP/DMG packaging, with an Applications shortcut, Gatekeeper checks and SHA-256 checksums. App version is `0.4.0`, build `4`. Public binary release remains gated on Apple acceptance and independent-Mac testing.

- Move demo explanations into short overlay boxes beside the pointer, removing the bottom subtitle strip.

- Replace the demo soundtrack with beat-led electro/IDM, keeping the mix quiet and the full URL ending covered.

- Finish the demo with a centered repository URL over Projects; extend the music through the final frame.

- Replaced the slide-style demo with a continuous portrait Night-mode walkthrough, real control clicks, conversational subtitles and quiet electronica. Clarified the desktop and command-line integration boundary.

- Refresh the public README, launch checklist and contributor entry points. Replace demo content with coherent fictional projects; add reproducible captioned demo video production.
- Derive notarized archive filenames from the built app version and reject non-Developer-ID signing identities before building.

- Discover local agent-created top-level Codex chats and scheduled runs, including tasks without a saved project. Continue excluding internal subagents and reviews. Document the separate limitation for cloud-backed histories that execute on a local Mac.

- Replace Photos with Art details: 19 contemporary works from six artists, with documented artist releases, curated close-ups in original color, hourly rotation and a credited art picker. Existing appearance preferences carry over.
- Identify the current background with a small, linked artwork/artist/date caption at the bottom of Focus and full-board views.

- Recognize Claude background-task completions delivered as queued attachments, preventing finished conversations from remaining Running or Status unavailable after history replay.
- Park old conversations confirmed missing from a complete source inventory, preserving their history and notes while keeping genuine read failures visible.
- Ready to check and Needs me cards summarize the latest agent report, with separate request-history summaries and cached report excerpts.

- Add a compact, left-aligned banana mark and kanbanana title to Focus mode.
- Tighten the gap between project and conversation titles, and add a one-click Dealt with action to every card.
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
