# Public launch checklist

This repo is already public. Source builds are available; the signed macOS download is not yet released. This checklist separates preparation from evidence required before announcing a downloadable app.

## Ready in the repository

- [x] Focus-first README with local build instructions and a clear source-beta label.
- [x] Architecture, contribution, privacy, security and troubleshooting documentation.
- [x] Fictional demonstration data, synthetic screenshots and a reproducible video renderer.
- [x] Per-work art attribution, permission evidence and bundled runtime licenses.
- [x] Swift/Python CI and secret scanning; no real API key needed for tests.

## Before the first downloadable beta

- [ ] Apple Developer enrollment is active (purchase receipt alone is insufficient).
- [ ] Developer ID Application certificate and private key are available in Keychain.
- [ ] A notarytool Keychain profile is configured; credentials stay out of the repo and CI logs.
- [ ] Choose a new release version and increase CFBundleVersion in `scripts/build.zsh`.
- [ ] Complete the signed ZIP path in [RELEASING.md](RELEASING.md), including Apple's acceptance, stapling and Gatekeeper assessment.
- [ ] Add and validate the planned DMG with an Applications shortcut. The current script produces ZIP only.
- [ ] Run the exact downloaded artifact on independent Macs: Claude-only, Codex-only and both. Record provider/OS versions and results.
- [ ] Verify onboarding, source access, cold-start navigation, question/permission/resume/delivery states, Keychain persistence, sleep/wake and upgrade preservation.
- [ ] Settle the intended supported scope. Cloud-backed Codex conversations are currently excluded even when their code runs locally.
- [ ] Publish the new GitHub prerelease with download, SHA256SUMS, requirements, installation steps, known limitations and recovery instructions.
- [ ] Update README and demo end-card only after that download exists.

## Launch on X

The video in `docs/media/` is captioned and silent, 1920×1080 H.264. It is rendered from real application views using fictional data. Read [DEMO.md](DEMO.md) before regenerating or editing it.

1. Download and watch the final video all the way through. Ensure its source/download wording matches the release.
2. Open the GitHub link while signed out. Check the README, video, download and issue templates.
3. Use the draft below as a starting point; the maintainer reviews the exact post and media before publishing.
4. After publishing, collect reproducible feedback and sanitized diagnostics. Do not ask people to post conversation histories.

### Draft for the current source beta

> I made kanbanana to keep up with Claude Code and Codex: what's running, what came back, and what needs me. A little Mac window with projects and reminders.
>
> Open source · Apple Silicon · build locally for now.
> https://github.com/laurenceholt/kanbanana

This is draft copy, not a posted announcement. Shorten to fit the account's posting limit; keep the source-beta qualifier. For the downloadable launch, replace the final line with a truthful download invitation and link to the tested release. Do not describe all Codex conversations as supported.
