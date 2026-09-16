# Troubleshooting and recovery

## No cards

Complete onboarding, confirm a provider is enabled in Settings, and start a local conversation in Claude Desktop's Code section or Codex Desktop. Discovery initially covers two weeks. Settings → Find older conversations expands the range. Clear search/project filters; parked items live behind the archive-box button in the full board.

If you use a custom `CODEX_HOME` or `CLAUDE_CONFIG_DIR`, enter it under Settings → Custom session locations. Do not point the app at another person's data.

## Connection health

- **Not installed:** no expected source store/app was found. Disable an unused provider. App versions in Settings use macOS bundle discovery.
- **No local sessions:** the app exists but its local store has not been created. Create a local task and retry.
- **Access denied:** macOS or filesystem permissions prevented reading. Review the relevant file-access prompt or permissions. Broad Full Disk Access is not a default requirement.
- **Unsupported format:** a required schema is unknown. Check for a kanbanana update and attach sanitized diagnostics to an issue. Repeated retries cannot repair an incompatible schema.
- **Unavailable / updates paused:** a temporary database or process failure. Retry status restarts the reader and clears its caches. Prior board data remains.
- **No recent execution signal:** the store can be read but it does not establish whether that quiet task is still running. Open the source conversation to check.

## Summaries

Saving a key does not enable summaries. Enable the toggle explicitly after reading the privacy information. If the daily attempt limit is reached, wait until the next local calendar day or change the limit. Excluded projects remain excerpts unless already cached.

An empty replacement-key field does not mean the saved key is missing; the status label indicates whether Keychain has it. A development rebuild can trigger a new macOS Keychain authorization prompt. Approve it yourself if you trust the build. Retry summaries after correcting key, model, quota or access issues. The app never displays the saved key.

## Backup and restore

Settings → Export board writes a complete board snapshot, excluding the API key and assistant responses. Keep it private. Settings → Restore validates a selected JSON export, backs up the current board, restores projects/notes/dispositions and turns cloud summaries off. Source apps are unchanged. A rescan can then update task activity.

Up to seven backups live in `~/Library/Application Support/Agent Kanban/Backups/`. Automatic backups are at most hourly; restoration forces a backup. Backups are previous snapshots, not a guarantee that the last edit before a force quit is present. Back up exports separately if you need longer retention.

If the current board is corrupt or has an unsupported version, saving is disabled to preserve it. Restore a valid backup through Settings. The original unreadable file is preserved in `Recovery/` before replacement. Do not hand-edit a working board while the app is running.

## Hung or hidden app

Closing the window does not quit. Click its menu-bar item to reopen. Quit from Settings, or force-quit kanbanana if unresponsive, then double-click the same app bundle. The saved board reloads. A force quit may lose a very recent edit that had not yet autosaved.

## Safe bug reports

Settings → Diagnostics exports app/OS/provider versions, aggregate counts and fixed health categories. Review the file before attaching. Never attach `board.json`, backups, raw reader output, transcripts, keys or screenshots with private cards. The reader's stdout is a private application data pipe and contains request text.
