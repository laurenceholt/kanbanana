# Contributing

This is an early, independently maintained macOS utility. Small fixes, reproducible reports and synthetic integration fixtures are especially useful. Open an issue before a substantial feature or architecture change.

Use zsh for shell examples. Build on Apple Silicon with Xcode command line tools (Swift 6.0+). Run the commands in README before submitting a pull request. CI builds the app in Swift 6 language mode and runs independent Core/Services tests, app tests and the Python suite. Tests must not require a real API key or a user's session stores.

Start with `swift run AgentKanban --demo` for UI work. It uses temporary data, no native session reader and no Keychain or cloud access. `zsh scripts/previews.zsh` renders synthetic screenshots. `python3 -I -B scripts/benchmark-reader.py` exercises a generated large history. Read [Architecture](docs/ARCHITECTURE.md) before changing service boundaries.

- Keep Core free of AppKit/SwiftUI and side effects; views send commands through the coordinator.
- Keep source integrations read-only. Never fix monitoring by editing another app's database or configuration.
- Preserve user notes, dispositions and cached history when observations fail. Unknown status must not imply completion.
- Use synthetic or carefully redacted fixtures; never commit actual conversations, keys, board exports or diagnostics containing private material.
- Cover changes to persistence, privacy, billing limits and status interpretation with meaningful tests.
- Preserve existing saved boards; reject newer unsupported formats without overwriting them.
- Respect Reduce Motion, keyboard access and macOS accessibility labels.
- Changes to bundled photos/runtime components must include provenance, license notices and reproducible download hashes.

Pull requests are welcome under the MIT license. Maintainers may request a smaller scope. There is no guaranteed response time or support SLA. To report a vulnerability, follow SECURITY.md instead of a public issue.
