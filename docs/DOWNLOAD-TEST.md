# Downloadable beta acceptance check

Use the exact release artifact on an Apple Silicon Mac running macOS 14 or later. A second physical Mac is required before advertising broader binary compatibility. Do not use real conversation screenshots or exports in public reports.

## Install

1. Download the DMG or ZIP through a browser so macOS applies its normal download checks. Do not remove quarantine attributes or disable Gatekeeper.
2. Open the DMG and drag kanbanana to Applications (or unzip and move the app there). Quit a previous copy first. If upgrading, keep its data folder and choose Replace for the app only.
3. Eject the disk image, then open the installed copy. Expect the ordinary first-open confirmation identifying the developer, with no unidentified-developer or damaged-app error.
4. A new installation should offer provider selection before reading source records. An upgrade should preserve the board, project assignments, notes, priorities and settings.

## Exercise the supported workflow

- Test a Claude-only Mac, a Codex-only Mac, and a Mac with both providers. Record the app and macOS versions; one machine can cover more than one configuration, but a separate physical Mac is still needed.
- Start a local conversation, observe Running, ask a question that requires a reply, then deliver a result. Check Needs me where the source records expose the wait, and Ready to check after delivery.
- Open a card with the native app closed; verify it opens the correct conversation.
- Mark a card Dealt with, send another request, and verify reactivation. Add a To do note and a project goal; relaunch and verify both persist.
- If using cloud summaries, enable them explicitly with your own API key. Verify summaries and Keychain persistence after relaunch. Saving the key alone must not enable cloud processing.
- Sleep and wake the Mac during a run; verify monitoring recovers without losing notes or assignments.
- Try the Focus and Projects layouts, resizing, and your usual display arrangement.

## Report

Record artifact filename and SHA-256, Mac architecture, macOS version, provider versions, fresh install or upgrade, and pass/fail for each step. Include sanitized diagnostics for failures. Never attach a board export, API key, or conversation history to a public issue.

Cloud-backed Codex histories (including some tasks executing on a connected Mac), standalone Claude Code CLI discovery and Intel Macs are outside this beta's supported scope. See [COMPATIBILITY.md](COMPATIBILITY.md).
