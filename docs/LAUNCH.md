# Public launch checklist

The source repository is public. The **0.4.9 (build 13)** candidate is being prepared as a private GitHub draft release, `v0.4.9-beta.1`. Do not publish it or announce a public download until the MacBook Air acceptance test passes.

## Supported first downloadable beta

- Apple Silicon, macOS 14 or later.
- Claude Desktop **Code** conversations with local Desktop metadata and readable transcripts.
- Codex Desktop conversations with supported local history, including top-level tasks outside saved projects.
- Optional OpenAI summaries with explicit consent and your own API key.
- ChatGPT monitoring remains an **off-by-default experiment**, outside the supported launch scope. No promise of complete cloud, remote, terminal-only or cross-Mac discovery. Intel builds are not provided.

## Candidate preparation

- [x] Public source, architecture/contribution/privacy/security documentation and bundled asset/runtime licenses already exist.
- [x] A fictional-data, phone-friendly demo and screenshots already exist.
- [x] Developer ID and notarization setup previously verified; reuse existing credentials.
- [x] Select current stability fixes and prepare 0.4.9/build 13 on `codex/release-0.4.9`.
- [x] Make ChatGPT monitoring explicitly opt-in and test upgrade behavior.
- [x] Pass local Swift/Python tests and secret scanning on the final candidate (118 Swift / 61 Python; November 25).
- [ ] Pass GitHub CI for the candidate commit on macOS 14 and 15.
- [ ] Sign and notarize the exact ZIP and DMG; validate stapled tickets, Gatekeeper and SHA-256 checksums.
- [ ] Put the artifacts and release notes in an **unpublished draft** for owner-only testing.

## MacBook Air acceptance

Use [DOWNLOAD-TEST.md](DOWNLOAD-TEST.md), one stage at a time. Prior Air installation proved the older download could launch; it did not test local agent discovery. An empty board with no local work is expected, not a failure.

- [ ] Download the candidate using the Air’s browser and install with normal Gatekeeper checks.
- [ ] Run a local test conversation on the Air, then verify discovery, delivery, exact navigation and a second round.
- [ ] Verify Focus/Projects, move/resize, project and To do notes, restart, and sleep/wake recovery.
- [ ] Verify optional summaries and saved-key persistence if using that feature in the test.
- [ ] Exercise Claude-only, Codex-only, and both enabled using Settings where the native apps are available; clearly record any untested combination.
- [ ] Record the tested artifact/hash, app/macOS/provider versions and results. Keep private conversation data out of public reports.

## Publish only after acceptance

1. Merge the tested candidate source and create a release tag at the exact tested source commit. Never move an existing tag.
2. Publish the prepared GitHub prerelease with the tested DMG, ZIP, checksums and limitations.
3. Replace README source-only wording with working download and installation links.
4. Check the repository, download and help links while signed out.
5. Review the existing 56-second demo for accuracy; retain its fictional data and desktop-only scope. Refresh images or video only if they misrepresent the candidate.
6. Review the final X post and media with Laurence, then publish only on his instruction.

## Draft X copy for the downloadable beta

> I made kanbanana to keep up with Claude Code and Codex: what's running, what came back, and what needs me. A little Mac window with projects and reminders.
>
> Open source. Free macOS beta for Apple Silicon.
> https://github.com/laurenceholt/kanbanana

This remains draft copy. It is not a posted announcement. Do not promise every chat, ChatGPT support, or terminal-only coverage. Collect sanitized diagnostics and reproducible issues after launch.
