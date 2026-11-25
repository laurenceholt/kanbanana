# Downloadable beta acceptance check

Use the exact release artifact on an Apple Silicon Mac running macOS 14 or later. A second physical Mac is required before advertising broader binary compatibility. Do not use real conversation screenshots or exports in public reports.

## Guided MacBook Air test for 0.4.9 (build 13)

We will do these stages one at a time. Do not start until the draft release contains the **notarized** `kanbanana-0.4.9-arm64.dmg`. Sign in to GitHub as the repository owner to access an unpublished draft; it is not a public download.

### Stage 1 — install and open

1. On the Air, quit an older kanbanana using **Settings → Quit** if it is running.
2. Download the candidate DMG from the draft release using the Air’s browser. Open the downloaded file.
3. Drag **kanbanana** onto **Applications** in the disk image. Choose **Replace** if offered. Keep the app’s existing data; do not delete its support folder.
4. Eject the kanbanana disk image in Finder, then open **Applications → kanbanana**. Accept the normal macOS first-open confirmation. Stop and report any damaged-app, unidentified-developer or security-block message; do not bypass it.
5. If onboarding appears, select the supported apps installed on the Air. An empty board is expected if your work lives on the Studio. No API key is needed for this stage.
6. Move the window and resize it in Focus and Projects. Report whether the app opened normally and the window moves/resizes.

### Stage 2 — one local conversation

1. In Finder, create an empty folder named **kanbanana-test** in Documents.
2. Open that folder as a local project in **Claude Desktop’s Code section** or **Codex Desktop** on the Air. Use the Air as the execution location, not the Studio. Ordinary ChatGPT chat is outside this test.
3. Send: **“For a local kanbanana test, run a shell command that waits 30 seconds, then create TEST.txt containing ‘First round complete’. Tell me when it is done.”**
4. While it runs, check kanbanana’s **Running** category. After delivery, check **Ready to check**. Click its card and confirm that the correct conversation opens.
5. Mark the card **Dealt with**. In the same conversation send: **“Append ‘Second round complete’ to TEST.txt and tell me when done.”** Confirm it reappears, then reaches Ready to check.
6. Send: **“Before changing anything, ask me which word to append: banana or mango. Wait for my answer.”** Check Needs me if the source exposes the wait; answer **banana** and check that the result returns to Ready to check. Record missing states rather than assuming they worked.

If the card does not appear, stop at this stage and report the provider and the source status shown in Settings. Do not create many extra conversations or add an API key to try to fix discovery.

### Stage 3 — persistence and recovery

1. Add a project goal and a To do note, star the card, and change the background.
2. Quit and reopen kanbanana. Confirm your notes, star, theme and assignments remain.
3. Close the Air’s lid briefly, reopen it, and run another short request. Confirm monitoring resumes.
4. If you use optional summaries, enable them with your own key through Settings, check one summary, then relaunch. A blank SecureField is normal; the saved-key indicator should still say the key is saved. Never paste the key into a chat.
5. Repeat the local-conversation stage in the other supported app if it is installed. Use Settings to test one provider enabled at a time and then both.

The full checklist below records the release evidence. Keep fictional test data and any private diagnostics out of public issues.

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
