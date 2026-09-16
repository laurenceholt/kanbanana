import KanbananaCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.boardAppearance) private var appearance
    @ObservedObject var store: BoardStore
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var model = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Settings").font(.title2.bold()); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }
            ScrollView { VStack(alignment: .leading, spacing: 14) {
            Text("OpenAI summaries").font(.headline)
            Text("When enabled, request text goes directly to OpenAI using your paid API key. Project notes stay on your Mac. The key is stored in macOS Keychain. Saving a key does not enable summaries.").font(.caption).foregroundStyle(.secondary)
            Label(store.credentialStatus.message, systemImage: store.credentialStatus == .saved ? "checkmark.shield" : "key")
                .font(appearance.font(12, weight: .semibold)).foregroundStyle(store.credentialStatus == .saved ? appearance.accent(ProjectColor.palette[0].accent) : appearance.ink)
            HStack {
                SecureField(store.credentialStatus == .saved ? "Paste a replacement key" : "OpenAI API key", text: $key).disabled(store.savingKey)
                Button(store.savingKey ? "Saving…" : store.credentialStatus == .saved ? "Replace key" : "Save key") {
                    Task { if await store.saveKey(key) { key = "" } }
                }.disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.savingKey)
            }
            Text("The saved key stays hidden. Leave this field empty to keep using it.").font(.caption).foregroundStyle(appearance.muted)
            HStack {
                Text("Model").font(.caption)
                TextField("GPT model", text: $model).onSubmit { store.setModel(model) }
                Button("Apply") { store.setModel(model) }.disabled(model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model == store.saved.model)
            }
            Button("Delete saved key", role: .destructive) { Task { await store.deleteKey() } }.disabled(store.credentialStatus == .missing || store.savingKey)
            Toggle("Enable request summaries", isOn: Binding(get: { store.saved.aiEnabled }, set: { store.setAIEnabled($0) })).disabled(store.savingKey)
            HStack(alignment: .top) {
                Text(store.aiStatus).font(.caption).foregroundStyle(appearance.muted).frame(maxWidth: .infinity, alignment: .leading)
                Button("Retry summaries") { store.retrySummaries() }.disabled(store.savingKey || store.isSummarizing)
            }
            Stepper("Daily summary limit: \(store.privacy.dailySummaryLimit)", value: Binding(get: { store.privacy.dailySummaryLimit }, set: { store.setDailyLimit($0) }), in: 1...1000, step: 10)
            Text("\(store.summaryAttemptsToday) attempts today. Each attempt can make up to two API calls. This is a request limit, not a dollar budget; prices depend on your model and request size.").font(.caption).foregroundStyle(appearance.muted)
            DisclosureGroup("Exclude projects from cloud summaries") {
                ForEach(store.saved.projects) { project in
                    Toggle(project.name, isOn: Binding(get: { store.privacy.excludedSummaryProjects.contains(project.id) }, set: { store.setSummaryExcluded(project.id, excluded: $0) }))
                }
                Text("Checked projects stay local. Existing cached summaries remain visible. Requests already sent cannot be recalled.").font(.caption)
            }
            Link("Privacy and OpenAI data handling", destination: URL(string: "https://github.com/laurenceholt/kanbanana/blob/main/PRIVACY.md")!)
            Divider()
            Text("Integrations").font(.headline)
            ForEach(["claude", "codex"], id: \.self) { p in HStack { Text(p == "claude" ? "Claude Code" : "Codex Desktop"); Spacer(); Text(store.health[p] ?? "Connecting").foregroundStyle(.secondary) }.font(.caption) }
            IntegrationOptions(store: store)
            Text("Beta: reads local history. Live approval signals and exact navigation are still being validated. Quiet, unfinished turns show status unavailable.").font(.caption).foregroundStyle(.secondary)
            DataControls(store: store)
            HStack {
                Button("Find older conversations") { store.startReader(days: 3650); dismiss() }
                Button("Show local data") { NSWorkspace.shared.open(store.root) }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }.font(.caption)
            } }
        }.font(appearance.font(12)).textFieldStyle(.roundedBorder).padding(24).frame(width: 550, height: 620).background(appearance.canvas).foregroundStyle(appearance.ink)
            .task { model = store.saved.model; await store.refreshKeyStatus() }
    }
}
