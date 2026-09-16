# Releasing

## Source beta

1. Run Swift and Python tests, build, and run `zsh scripts/audit.zsh`.
2. Review the entire public tree and history for personal material; secret scanning does not review screenshots or ordinary private text.
3. Regenerate synthetic screenshots with `zsh scripts/previews.zsh` and inspect them.
4. Update version, changelog and dated compatibility evidence. Verify fresh-run onboarding, privacy controls, ordinary navigation, persistence and recovery.
5. Publish a GitHub prerelease tagged `v0.3.0-beta.1`. Source-only releases must clearly say they have no signed download.

CI runs on macOS 14 and 15 using synthetic data and an isolated runtime. No production API key, signing identity or user data is needed.

## Signed app download

An Apple Developer membership, Developer ID Application certificate/private key, and a notarytool credential profile are required. Install/import those through Apple's tools; never commit them or paste credentials into an issue or script.

```zsh
KANBAN_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
KANBAN_NOTARY_PROFILE='kanbanana-notary' \
zsh scripts/notarize.zsh
```

The build signs embedded Mach-O files inside-out, enables hardened runtime when a Developer ID is supplied, and verifies the staged bundle. Notarization submits a ZIP, waits for acceptance, staples and validates the ticket, runs Gatekeeper assessment, and creates the final archive plus SHA256SUMS.

The default `build.zsh` uses ad-hoc signing for local development. That is not Developer ID signing and not notarization. Do not upload that output as the signed release. The notarization path must be tested with a real identity before advertising downloadable support.

Test the final downloaded artifact on a separate clean Mac, including source access, Keychain access, relocation to Applications and an upgrade preserving existing notes. Add checks for sleep/wake, cold-start deep links, source upgrades and single-provider installations. Wider-beta physical testing remains a release gate for a supported binary.

## Release hygiene

Preserve `com.laurenceholt.agent-kanban` and the existing data/Keychain service names when upgrading. Keep runtime hashes and license files in sync. The runtime and all photos are bundled; no runtime downloader is added. Bump CFBundleVersion for each distributed app. GitHub Releases is the update channel; this beta has no automatic updater.

## Pilot checklist

Ask a small group of volunteers using different Mac/provider setups to try the source beta. Give them a short task: install, observe a run, handle a question, open a result, add a note, relaunch, export/restore. Collect sanitized diagnostics and the exact versions. Record unmet expectations rather than treating a green CI run as a usability trial. Invitations are not sent automatically.
