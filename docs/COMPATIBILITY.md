# Compatibility and limitations

Status for the 0.3.0 source beta, 16 September 2026. Compatibility is based on observed stores and tests, not an official integration contract.

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
