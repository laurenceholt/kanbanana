# kanbanana 0.4.9 beta 1 — release candidate

**App version:** 0.4.9 · **Build:** 13 · **Platform:** Apple Silicon, macOS 14+

This candidate collects the fixes used in daily work since the earlier download: native Mac window activation, current Codex history after a conversation continues into a new segment, useful capacity-error explanations, and protection against launching obsolete upgrade backups.

ChatGPT monitoring is an off-by-default experiment, not part of the supported beta. Existing experimental cards and curation survive upgrades, but monitoring now requires explicit opt-in in Settings.

## Install and upgrade

Download `kanbanana-0.4.9-arm64.dmg`, open it, and drag kanbanana to Applications. Quit an older running copy before replacing it. Eject the disk image and launch the installed app. The ZIP is an alternative containing the same app. Normal macOS first-open confirmation is expected; do not bypass Gatekeeper or remove quarantine attributes.

The app preserves the existing `Agent Kanban` local data folder and Keychain service. Do not delete your data when upgrading. You can export your board from Settings before upgrading and keep that export private.

## What to expect

Start or continue conversations in Claude Desktop’s Code section or Codex Desktop **on this Mac**. A first board can be empty; kanbanana does not import work from your other Mac. An API key is unnecessary for discovery. Optional paid summaries require your own OpenAI API key and explicit opt-in.

Click a card to open its conversation. Focus is the narrow view; the expand arrows open Projects. Use the palette to change appearance, the star to prioritize, and the check button to mark a round Dealt with. To do and project notes stay local.

## Known limitations

- Claude Chat/Cowork, standalone Claude CLI discovery, Intel Macs and complete cloud/remote history coverage are outside this beta’s scope.
- Codex CLI records may appear when stored in the supported local format; a terminal-only workflow is not promised, and navigation opens the desktop app.
- Status relies on native local records; some permission prompts are not exposed. Quiet or ambiguous work can show Status unavailable. Ready to check is not proof of correctness or a Git push.
- Experimental ChatGPT cards have limited metadata and no message summaries or dependable complete status coverage.
- No cross-Mac sync or automatic updater. Get future versions through GitHub Releases.

Report reproducible issues with app/OS/provider versions and sanitized diagnostics. Never post API keys, board exports or private conversation screenshots.

## Acceptance status

**Unpublished candidate. MacBook Air acceptance is pending.** Automated, signing and CI evidence will be recorded in `docs/COMPATIBILITY.md`; publish only after the exact downloaded artifact passes the test.
