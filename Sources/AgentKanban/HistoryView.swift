import KanbananaCore
import SwiftUI
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(\.boardAppearance) private var appearance
    @ObservedObject var store: BoardStore
    let cardID: String
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let card = store.cards.first(where: { $0.id == cardID }) {
                HStack { Text(card.title).font(.headline).lineLimit(2); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }
                HStack {
                    ProviderIcon(provider: card.provider, size: 22)
                    Label(store.project(card)?.name ?? "Ungrouped", systemImage: store.projectSymbol(store.project(card)).systemName).font(appearance.font(12.5, weight: .semibold)).foregroundStyle(appearance.project(store.projectColor(store.project(card))).accent)
                    Spacer()
                    Button("Open conversation") { store.open(card) }
                }.font(.caption)
                Divider()
                if card.requests.isEmpty { Text("The source did not provide readable request history.").foregroundStyle(.secondary) }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(card.requests.reversed()) { r in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(Date(timeIntervalSince1970: r.time).formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                                Text(store.summary(card, r) ?? String(r.text.prefix(360))).font(.system(size: 12)).textSelection(.enabled)
                                DisclosureGroup(store.summary(card, r) == nil ? "Original request · not yet summarized" : "Show original request") {
                                    Text(r.text).font(.system(size: 11)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                }.font(.caption).foregroundStyle(.secondary)
                            }
                            Divider()
                        }
                    }
                }
                if let issue = store.historyError[cardID] {
                    HStack { Text(issue).font(.caption); Button("Retry") { Task { await store.loadHistory(cardID) } } }
                }
                if store.historyLoading.contains(cardID) { ProgressView().controlSize(.small) }
                else if store.historyHasMore[cardID] == true {
                    Button("Load earlier requests") { Task { await store.loadHistory(cardID, earlier: true) } }
                }
                HStack { Text("\(card.requests.count) loaded requests · newest first").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Summarize history") { store.summarizeHistory(card) }.disabled(!store.saved.aiEnabled) }
            }
        }.font(appearance.font(12)).padding(20).frame(width: 520, height: 470).background(appearance.canvas).foregroundStyle(appearance.ink)
            .task(id: cardID) { await store.loadHistory(cardID) }
    }
}
