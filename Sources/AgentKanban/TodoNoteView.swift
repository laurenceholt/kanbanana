import KanbananaCore
import SwiftUI
import UniformTypeIdentifiers

struct TodoNoteView: View {
    @Environment(\.boardAppearance) private var appearance
    let store: BoardStore
    let card: Conversation
    @State private var note: String
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    init(store: BoardStore, card: Conversation) {
        self.store = store; self.card = card
        _note = State(initialValue: store.disposition(card).todoNote ?? "")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("To do note", systemImage: "note.text").font(appearance.font(19, weight: .semibold))
            Text(card.title).font(appearance.font(12, weight: .semibold)).lineLimit(2)
            Text("What’s the next round? Leave this blank if you prefer.").font(appearance.font(12)).foregroundStyle(appearance.muted)
            TextField("Add a reminder for this conversation…", text: $note, axis: .vertical)
                .lineLimit(3...6).textFieldStyle(.plain).font(appearance.font(13)).padding(12)
                .background(appearance.paper, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(appearance.line, lineWidth: 1))
                .focused($focused).accessibilityLabel("To do note")
            HStack {
                if store.disposition(card).todoNote != nil {
                    Button(role: .destructive) { store.setTodoNote(card.id, ""); dismiss() } label: {
                        Label("Delete note", systemImage: "trash")
                    }.help("Delete this To do note")
                } else {
                    Text("Saved with this card.").font(appearance.font(10)).foregroundStyle(appearance.muted)
                }
                Spacer()
                Button("Not now") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Done") { store.setTodoNote(card.id, note); dismiss() }.keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 440).background(appearance.canvas).foregroundStyle(appearance.ink)
            .onAppear { focused = true }
    }
}
