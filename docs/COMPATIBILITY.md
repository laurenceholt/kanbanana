# Compatibility and limitations

Status for the 0.2.0 source beta, 15 September 2026. Compatibility is based on observed stores and tests, not an official integration contract.

| Component | Evidence / support |
| --- | --- |
| Apple Silicon, macOS 26.1 | Local development, native UI use, bundled-runtime build and automated tests. |
| macOS 14 / 15 | Build target and CI matrix. Check the current Checks run for results; a green build does not verify native provider transitions on that OS. |
| Intel Mac | Not packaged or tested in this beta. |
| Claude Desktop Code 2.110.0 | Local session discovery and request history; previously verified exact local-session navigation. |
| Codex desktop bundle `com.openai.codex`, version 26.901.31953 | Local discovery, legacy and paginated histories. The installed app may be named ChatGPT; integration uses its bundle identity. |
| Claude Chat / Cowork | Not supported. |
| Remote, SSH, cloud-only sessions | No completeness guarantee. Only locally accessible records can appear. |

## Integration contract

Claude reads Desktop metadata under `~/Library/Application Support/Claude/claude-code-sessions` and transcript JSONL under `~/.claude/projects`. Codex reads `~/.codex/state_5.sqlite`, `thread_history_1.sqlite` where applicable, the session title index and referenced rollout histories. Settings accepts a custom Codex/Claude home. Desktop metadata remains at its normal path.

Native schemas and deep links are private implementation details and can change. Known Codex tables and columns are checked before querying. Unsupported formats and denied access are reported explicitly. Neither app's data or configuration is edited.

## What status can and cannot establish

- Running uses stored execution evidence. Background tasks are tracked beyond the parent's interim response.
- Ordinary unfinished turns without a fresh signal for two minutes become unavailable; explicit background tasks have a one-day quiet limit. Quiet is never interpreted as delivery.
- Needs me detects structured questions/errors and conservative required-input text. Some native permission dialogs never reach the stored history and cannot be reliably detected.
- Ready to check means a response appears delivered, not that the implementation is correct or pushed to GitHub.
- Disabling monitoring retains existing cards with their last observation; it does not delete source or board data. Summaries from that provider are also paused.

## Outstanding wider-beta checks

A second physical Mac, cold-start navigation across supported provider versions, full submit → permission → resume → delivery/error sequences, sleep/wake across long runs, multiple displays and Stage Manager still need broader hands-on coverage. Synthetic tests cover source outages, schema errors, mixed history formats and state preservation; they are not substitutes for those checks. Add a dated observation to this file when a configuration is verified.
