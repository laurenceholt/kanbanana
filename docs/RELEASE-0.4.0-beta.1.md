# kanbanana 0.4.0 beta 1 — downloadable candidate

**Draft release notes. Do not publish until notarization and the download acceptance checks are complete.**

kanbanana keeps locally stored Claude Desktop Code and Codex conversations together in a compact Mac window. See what is running, what came back, and what needs your attention; keep priorities, project goals and reminders alongside the conversations.

## Install

Requires an **Apple Silicon Mac and macOS 14 or later**. Intel builds are not included. No Xcode, separate Python installation or Apple Developer membership is required to run the packaged app.

1. Download `kanbanana-0.4.0-arm64.dmg`.
2. Open it and drag kanbanana to Applications. Quit an existing copy before replacing it.
3. Eject the disk image and open kanbanana from Applications. Choose the providers to monitor.

The ZIP contains the same app for people who prefer it. Optional AI summaries require your own OpenAI API key and must be enabled explicitly in Settings. You can use the app with local excerpts and no API key.

## Changes since the previous source beta

- Developer ID signing and ZIP/DMG release packaging, with a bundled Python runtime.
- A compact Focus view with a banana title, tighter cards and a one-click Dealt with action.
- Ready to check and Needs me summaries describe the latest agent report.
- Local Codex tasks outside saved projects, including supported scheduled and agent-created top-level conversations.
- Better handling of Claude background-task completion and stale conversations confirmed missing from the source inventory.
- Nineteen licensed contemporary artworks with attribution, alongside Night and other appearance options.

## Known limits

- Claude support is for Desktop's **Code** section, not Chat or Cowork. Standalone Claude Code CLI sessions are not discovered.
- Codex support requires locally available records. Some conversations use cloud-backed history even when execution happens on your Mac; those are not captured. Local CLI records may appear, but cards open Codex Desktop.
- Status is inferred from local records. Some permission prompts are not visible to kanbanana. Ready to check does not verify correctness or whether changes were pushed.
- There is no automatic updater. Get updates from GitHub Releases.
- See [dated compatibility evidence](COMPATIBILITY.md) for the distinction between CI checks and hands-on testing.

## Upgrades and recovery

Replacing the app preserves `~/Library/Application Support/Agent Kanban/` and its existing Keychain settings. Do not delete that data directory during an upgrade. Settings offers board export, restore and sanitized diagnostics. Exports contain private text and should not be attached to public issues.

Use [the acceptance checklist](DOWNLOAD-TEST.md) for pilot testing and [troubleshooting](TROUBLESHOOTING.md) if a provider is unavailable. Report the app/provider/macOS versions with sanitized diagnostics.

`SHA256SUMS` accompanies the artifacts. From the folder containing both downloads, verify with `shasum -a 256 -c SHA256SUMS`.
