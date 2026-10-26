# Compatibility and limitations

Compatibility is based on dated observations and tests, not an official integration contract. The native-use matrix below records the September source-beta checks; later automated checks are listed separately.

## Onboarding update — 25 October 2026

Version `0.4.1`, build `5`, adds local-discovery onboarding, distinct empty states, Help links and guided summary setup. All 106 Swift tests (74 XCTest + 32 Swift Testing) pass with warnings treated as errors, along with all 50 Python tests. Synthetic renders were checked at Focus width and in the welcome/settings layouts. The guide uses synthetic data; no live API requests were made for this change. Apple accepted the 0.4.1 app ZIP and DMG on October 25; stapling, strict signature verification, checksums and Gatekeeper checks passed. The same source passed the macOS 14/15 CI matrix ([run](https://github.com/laurenceholt/kanbanana/actions/runs/40253300373)). The installed Mac Studio copy launches and its Focus Help menu was verified. A separate restart issue resurfaced nine previously acknowledged cards despite unchanged final conversation events; the nine marks were restored through the UI and verified against the pre-upgrade export. That export remains private for investigating the underlying issue.

## Release candidate checks — 19 October 2026

For app version `0.4.0` (build `4`, Apple Silicon), all 103 Swift tests passed with warnings treated as errors, all 50 Python tests passed, and the full Git history secret scan found no leaks. The Developer ID signed staging bundle passes deep/strict signature verification; its bundled Python reader passes an isolated empty-source smoke check without changing the signature. The same source commit passed the full macOS 14 and 15 CI matrix, including app packaging, secret audit and bundled-reader smoke checks ([run](https://github.com/laurenceholt/kanbanana/actions/runs/39271962103)). Apple accepted both the app ZIP and DMG on October 19; stapling and Gatekeeper checks passed. On October 25, the maintainer reported that this download installed and ran on a MacBook Air. Its board was empty, with the work believed to reside on a separate Mac Studio. This confirms a second-Mac installation, not provider discovery or the complete workflow; exact OS/provider versions were not supplied.

## Earlier automated checks — 18 October 2026

All 103 Swift tests (71 XCTest and 32 Swift Testing) passed with warnings treated as errors; all 50 Python tests passed. The bundled-runtime release build and isolated Focus/Projects screenshot rendering also passed. The fictional demo video was encoded, fully decoded without errors and inspected at sampled scenes. These checks do not establish Developer ID signing, notarization or compatibility on a second physical Mac.

## Native-use and CI evidence — September 2026

| Component | Evidence / support |
| --- | --- |
| Apple Silicon, macOS 26.1 | Local development and native UI use. On 16 September 2026, the refactored app was installed and launched over an existing v1 board: v2 migration preserved project records, assignments, priorities, to-do notes and summary settings; both readers connected and summaries resumed with the existing Keychain credential. Focus branding was checked in the running app. All 88 Swift tests, synthetic UI rendering and bundled-runtime build passed locally; 42 Python tests passed for the source beta. |
| macOS 14 / 15 | Apple Silicon CI: all 86 Swift tests and 42 Python tests, strict concurrency, app packaging, secret audit and bundled-reader smoke check passed on 16 September 2026 ([run](https://github.com/laurenceholt/kanbanana/actions/runs/35054817955)). This does not verify native provider transitions or GUI interactions on those OS versions. |
| Intel Mac | Not packaged or tested in this beta. |
| Claude Desktop Code 2.110.0 | Local session discovery and request history; previously verified exact local-session navigation. |
| Codex desktop bundle `com.openai.codex`, version 26.901.31953 | Local discovery, legacy and paginated histories. The installed app may be named ChatGPT; integration uses its bundle identity. |
| Claude Chat / Cowork | Not supported. |
| Remote, SSH, cloud-only sessions | No completeness guarantee. Only locally accessible records can appear. |

## Integration contract

Claude reads Desktop metadata under `~/Library/Application Support/Claude/claude-code-sessions` and transcript JSONL under `~/.claude/projects`. Codex reads `~/.codex/state_5.sqlite`, `thread_history_1.sqlite` where applicable, the session title index and referenced rollout histories. Settings accepts a custom Codex/Claude home. Desktop metadata remains at its normal path.

Native schemas and deep links are private implementation details and can change. Known Codex tables and columns are checked before querying. Unsupported formats and denied access are reported explicitly. Neither app's data or configuration is edited.

### Command-line sessions

Claude discovery starts from Desktop Code metadata and then reads its linked CLI transcript. A standalone Claude Code terminal session without that metadata is not discovered. Codex discovery explicitly includes `source = 'cli'` records in the supported local database, alongside `vscode` and `appServer`; synthetic reader tests cover inclusion. Navigation always uses a Codex Desktop deep link, not a terminal resume command. Terminal-only discovery, status transitions and resumption have not been validated end to end and are outside the promised desktop launch workflow.

### Codex tasks outside projects (17 October 2026)

Local top-level chats are discovered whether or not they have a saved Codex project. This includes user-started chats, agent-created top-level chats and scheduled runs; internal subagents and guardian reviews are excluded. Kanbanana initially groups a chat by its working folder, so its project label can differ from Codex's sidebar placement.

Some newer tasks use cloud-backed (durable) conversation history while executing against files on a connected Mac. Selecting that Mac as the execution location does not guarantee a local `state_5.sqlite` / history record. These chats are not currently supported by the local-file reader, and moving them into a sidebar project does not itself make their histories local. Supporting them requires a separate authenticated integration; kanbanana does not read the desktop app's login tokens. See [OpenAI's explanation of conversation sync and local file access](https://learn.chatgpt.com/docs/projects).

## What status can and cannot establish

- Running uses stored execution evidence. Background tasks are tracked beyond the parent's interim response. Both user-record and queued-attachment task notifications settle pending work; a subsequent parent report establishes delivery. Cold replay and incremental reads use the same classifier.
- Ordinary unfinished turns without a fresh signal for two minutes become unavailable; explicit background tasks have a one-day quiet limit. Quiet is never interpreted as delivery.
- Needs me detects structured questions/errors and conservative required-input text. Some native permission dialogs never reach the stored history and cannot be reliably detected.
- Ready to check means a response appears delivered, not that the implementation is correct or pushed to GitHub.
- Disabling monitoring retains existing cards with their last observation; it does not delete source or board data. Summaries from that provider are also paused.

## Outstanding wider-beta checks

A second physical Mac, cold-start navigation across supported provider versions, full submit → permission → resume → delivery/error sequences, sleep/wake across long runs, multiple displays and Stage Manager still need broader hands-on coverage. Synthetic tests cover source outages, schema errors, mixed history formats and state preservation; they are not substitutes for those checks. Add a dated observation to this file when a configuration is verified.
