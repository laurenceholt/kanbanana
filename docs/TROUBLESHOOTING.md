# Troubleshooting and recovery

## No cards

Complete onboarding, confirm a provider is enabled in Settings, and start a local conversation in Claude Desktop's Code section or Codex Desktop. Discovery initially covers two weeks. Settings → Find older conversations expands the range. Clear search/project filters; parked items live behind the archive-box button in the full board.

If you use a custom `CODEX_HOME` or `CLAUDE_CONFIG_DIR`, enter it under Settings → Custom session locations. Do not point the app at another person's data.

## Connection health

- **Not installed:** no expected source store/app was found. Disable an unused provider. App versions in Settings use macOS bundle discovery.
- **No local sessions:** the app exists but its local store has not been created. Create a local task and retry.
- **Access denied:** macOS or filesystem permissions prevented reading. Review the relevant file-access prompt or permissions. Broad Full Disk Access is not a default requirement.
- **Unsupported format:** a required schema is unknown. Check for a kanbanana update and attach sanitized diagnostics to an issue. Repeated retries cannot repair an incompatible schema.
- **Some histories unavailable:** a partial read, such as unreadable metadata or a transcript. Last observed task states and your notes remain intact; missing cards are not treated as confirmed deletions.
- **Unavailable / updates paused:** a database or process failure. Each provider has an independent worker. A worker that stops responding is marked stale after 20 seconds and restarted. Retry status immediately restarts workers and clears their memory caches. Prior board data remains.
- **No recent execution signal:** the store can be read but it does not establish whether that quiet task is still running. Open the source conversation to check.
- **No longer in Claude / Codex:** a complete inventory no longer contains that conversation. After seven days without activity it moves to the parking lot, retaining saved request history, notes and project assignment. To do reminders stay on the board; restoring a parked card gives it another seven days. These records do not count as retryable read failures. If new activity appears for the same source conversation, its card returns automatically. A renamed or replacement conversation with a different ID remains a separate card.

## A Codex card stays on an old request

Version 0.4.7 follows continued Codex history segments while retaining the original card. Earlier versions could show an old interruption even while the same conversation continued in Codex. Update if the card’s request/status remains old after Retry status. The fix preserves the card’s project assignment and notes.

## Model capacity and agent failures

When Codex records a failed turn, its card belongs in **Needs me**. Model-capacity failures show **Model at capacity** and the provider’s explanation. Open the conversation to change models or retry. A subsequent running or completed turn replaces that warning. The board shows the current state, not an error history; transient warnings that the provider does not save cannot be detected.

## Summaries

Saving a key does not enable summaries. Enable the toggle explicitly after reading the privacy information. If the daily attempt limit is reached, wait until the next local calendar day or change the limit. Excluded projects remain excerpts unless already cached.

An empty replacement-key field does not mean the saved key is missing; the status label indicates whether Keychain has it. A development rebuild can trigger a new macOS Keychain authorization prompt. Approve it yourself if you trust the build. Retry summaries after correcting key, model, quota or access issues. The app never displays the saved key.

## Backup and restore

Settings → Export board writes a snapshot of the loaded board and cached requests, including request/report summaries but excluding the API key and raw assistant responses. Keep it private. Settings → Restore validates a selected JSON export, backs up the current board, restores projects/notes/dispositions and turns cloud summaries off. Source apps are unchanged. A rescan can then update task activity.

Up to seven backups live in `~/Library/Application Support/Agent Kanban/Backups/`. Automatic backups are at most hourly; restoration forces a backup. Backups are previous snapshots, not a guarantee that the last edit before a force quit is present. Back up exports separately if you need longer retention.

Version 0.3 separates curation from cached history and backs up old v1 boards before migration. If `observations.json` is damaged, projects, notes and assignments still load; the app rebuilds observations from native sources. Earlier history is loaded in pages. To roll back to 0.2, quit 0.3 and restore a portable v1 backup/export; 0.2 cannot directly read the installed v2 document.

If the current board is corrupt or has an unsupported version, saving is disabled to preserve it. Restore a valid backup through Settings. The original unreadable file is preserved in `Recovery/` before replacement. Do not hand-edit a working board while the app is running.

## Hung or hidden app

Closing the window does not quit. Click its menu-bar item to reopen. Quit from Settings, or force-quit kanbanana if unresponsive, then double-click the same app bundle. The saved board reloads. A force quit may lose a very recent edit that had not yet autosaved.

## Old app copy is running

If a reader fix appears to regress, check which application copy is running. A runnable `.app` left in an upgrade-backup folder can be selected instead of the installed version. On November 7, an old backup reader held a completed Claude conversation in Running; launching the current installed copy restored Ready to check. Keep app backups as `.app-backup` folders or archives, unregister obsolete copies from Launch Services, and verify the running executable path after installation. Preserve the separate application-data backups.

## Focus window will not drag

Drag the native title bar at the top of the window. If cards still scroll and the sides/bottom resize, check whether screen mirroring is active. In one macOS setup, JetKVM mirroring (shown by the purple indicator) prevented Focus titlebar dragging while the full board still moved normally. Turning off that mirroring restored dragging immediately. This is an observed interaction, not a requirement to disable all screen sharing.

## Safe bug reports

Settings → Diagnostics exports app/OS/provider versions, aggregate counts and fixed health categories. Review the file before attaching. Never attach `board.json`, backups, raw reader output, transcripts, keys or screenshots with private cards. The reader's stdout is a private application data pipe and contains request text and the bounded latest agent report.
