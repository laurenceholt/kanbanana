# kanbanana development

This repository is the authoritative source for the refactored app and all future changes. The older `agent-kanban` / `kanbanana-development` repository is historical; do not copy new changes back into it or merge its history here.

- Use zsh for shell commands.
- Preserve the three SwiftPM target boundaries described in `docs/ARCHITECTURE.md`.
- Keep native integrations read-only and preserve user curation through observation failures.
- Use synthetic data for screenshots and tests. Never commit local boards, exports, keys, or native conversation content.
- Build with `zsh scripts/build.zsh`. Use `swift run AgentKanban --demo` or `zsh scripts/previews.zsh` for isolated UI work.
- The installed app is `~/Applications/kanbanana.app`. Quit an older running copy before launching an updated build. Preserve the existing bundle identifier and `~/Library/Application Support/Agent Kanban/` data directory.
