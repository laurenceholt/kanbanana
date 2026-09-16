# Architecture

A SwiftUI/AppKit menu-bar app owns the board and presentation. A bundled isolated CPython worker reads native stores every four seconds and sends JSON snapshots through a private pipe. No source configuration or databases are modified.

- `App.swift`, `WindowInteraction.swift`, `WindowLayout.swift`: window lifecycle, activation clicks, placement and menu bar.
- `Views.swift`, `FocusView.swift`, `ProjectLanes.swift`, `ProjectStacks.swift`: board surfaces.
- `Model.swift`: separate observations, manual dispositions, projects, requests and summaries; pure lifecycle reducer.
- `Store.swift`: reconciliation, worker restart, provider controls, summary queue and privacy limits.
- `Persistence.swift`: serialized atomic writes, validation, bounded backups and restoration. Durable assistant response fields are blanked.
- `Credentials.swift`: asynchronous Keychain operations; secrets never enter board files.
- `Summaries.swift`: OpenAI Responses client, direct request reminders, bounded retries and safe error messages.
- `ReleaseSupport.swift`: onboarding, release controls, diagnostics and banana artwork.
- `Resources/reader.py`: native-source adapters, schema checks, conservative state interpretation and bounded diagnostic health log.

App-owned state is a versioned JSON document. Native SQLite connections use read-only mode and `query_only`; history caches avoid re-parsing unchanged transcripts. Missing observations preserve curation and are never treated as successful completion. A user request supersedes an old manual acknowledgement; To do is always manual.

Summary input is the single user request, not the whole conversation. Request hashes invalidate changed text. Exclusions and provider toggles apply to all queues. The persistent daily attempt reservation is written before an outbound operation; an API retry can occur once within that attempt. Current generation IDs discard results after cancellation. Existing users retain enabled settings on upgrade; new installs require explicit enablement.

Synthetic tests run without credentials or native session stores. `scripts/render-preview.swift` renders fictional board data into screenshots without changing the live app's preferences. Include `ReleaseSupport.swift` when compiling it; `scripts/previews.zsh` is the supported command.
