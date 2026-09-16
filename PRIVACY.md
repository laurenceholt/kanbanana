# Privacy

kanbanana is a local macOS companion. It has no account system, analytics SDK, telemetry service or developer-operated backend.

## What it reads and saves

After onboarding, the selected integrations read local conversation metadata and histories from Claude Desktop Code and Codex. Source databases are opened read-only; native settings, permissions and conversations are not modified. Other products such as Claude Chat/Cowork are outside this beta's scope.

The local board stores conversation titles, identifiers, folder paths, user request text, summaries, project notes, assignments and manual states. Assistant response text is used transiently to classify status but is removed before the board is saved. Source histories may contain tool records needed to interpret execution; those records are not sent to the summary API.

`~/Library/Application Support/Agent Kanban/` contains:

- `board.json`: current board, including original requests and notes.
- `Backups/`: up to seven previous valid boards. At most one automatic backup per hour; restoration forces another backup.
- `status-health.json`: at most 50 changes in connection health and aggregate state counts.

Board files use owner-only permissions, but are not independently encrypted. Your Mac's account access, FileVault and backup configuration determine protection at rest. macOS preferences store window and appearance choices. OpenAI keys are stored separately in macOS Keychain; exports never include them.

## Optional cloud processing

Cloud summaries are off until you explicitly enable them in Settings. Saving a key does not enable processing. When enabled, each request selected for summarization is sent to `https://api.openai.com/v1/responses`, with a short summarization instruction, your selected model and your API key for authorization. This includes text you pasted into the request. Treat anything in that request as eligible to be sent.

Project notes, To do notes, source credentials, tool outputs and assistant responses are not part of the summary input. Excluded projects and disabled providers are omitted from new summary work. Exclusion does not recall a request already sent or delete a cached summary.

The API request uses `store: false`. This does **not** promise zero retention: OpenAI's default abuse-monitoring retention can still apply. Consult [OpenAI's current data controls](https://platform.openai.com/docs/guides/your-data) and your account's terms. kanbanana cannot override that policy.

Latest requests are summarized automatically. Older unsummarized history is opt-in. Existing cached summaries may be refreshed after a summary-format update. A persistent daily attempt cap covers automatic summaries, history and refreshes. An attempt can retry once; prices depend on request length and model. OpenAI bills your API account directly.

## Other network activity

Opening a conversation invokes the native app's URL scheme. Source/credit/documentation links open only when clicked. Photos are bundled and never downloaded or generated at runtime. There is no automatic update checker in this beta.

Building from source downloads a pinned Python runtime from GitHub. Development tools and CI may also download their declared dependencies. These are build-time actions, not background app behavior.

## Export, diagnostics and deletion

Board exports and backups contain private request text and notes. Do not attach them to public issues. Settings → Diagnostics exports only app/OS/provider versions, counts and a fixed connection-health vocabulary; no titles, IDs, paths, requests, notes, key or arbitrary error strings.

To remove the key, choose Settings → Delete saved key. To remove all local board data, quit kanbanana, remove `~/Library/Application Support/Agent Kanban/`, and remove the app if you no longer want it. Remove board exports wherever you saved them and account for your own system backups. Source conversations are unaffected. Relaunching an installed app can rediscover local sessions after onboarding.
