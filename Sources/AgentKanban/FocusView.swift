import KanbananaCore
import SwiftUI

extension BoardStore {
    // Focus always shows the whole active board, even when the full board has
    // a project, search, or parking filter. Keep individual conversations flat.
    func focusCards(in column: Column) -> [Conversation] {
        CardOrder.sorted(cards.filter { !disposition($0).parked && self.column($0) == column }, dispositions: saved.dispositions)
    }
}

struct FocusBoard<CardContent: View>: View {
    @Environment(\.boardAppearance) private var appearance
    @ObservedObject var store: BoardStore
    @Binding var background: BoardBackground
    @Binding var cardPaper: CardPaper
    @Binding var theme: BoardTheme
    @Binding var photoOffset: Int
    let photoContext: String
    let changeLayout: (BoardLayout) -> Void
    let cardContent: (Conversation) -> CardContent
    @State private var expanded: Column = .ready
    @State private var showConnectionDetails = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var columns: [Column] { Column.board + (store.count(.unknown) > 0 ? [.unknown] : []) }
    private var connectionMessage: String {
        ([store.error, store.readerError].compactMap { $0 } + store.sourceWarnings).joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                BananaMark().frame(width: 16, height: 16)
                Text("kanbanana").font(appearance.font(13, weight: .semibold)).tracking(-0.3)
            }
            .foregroundStyle(appearance.ink)
            .frame(maxWidth: .infinity, alignment: .leading).frame(height: 28)
            .padding(.horizontal, 18).padding(.top, 23)
            .accessibilityElement(children: .combine)

            HStack(spacing: 2) {
                ForEach(columns, id: \.self) { column in columnHeader(column) }
            }.padding(.horizontal, 8).padding(.bottom, 3)

            HStack(spacing: 4) {
                Text(expanded.title.uppercased()).font(BoardStyle.label(8)).lineLimit(1).tracking(0.7).foregroundStyle(appearance.muted)
                Spacer(minLength: 0)
                if !connectionMessage.isEmpty {
                    Button { showConnectionDetails.toggle() } label: {
                        Image(systemName: "exclamationmark.circle").foregroundStyle(.orange)
                    }.buttonStyle(QuietIconButton()).help(connectionMessage).accessibilityLabel("Connection details")
                        .popover(isPresented: $showConnectionDetails) {
                            Text(connectionMessage).font(appearance.font(11)).padding(16).frame(width: 260)
                        }
                }
                Button { store.retryStatus() } label: {
                    Image(systemName: "arrow.clockwise").opacity(store.scanning ? 0.35 : 1)
                }.buttonStyle(QuietIconButton()).disabled(store.scanning).accessibilityLabel("Retry status")
                    .help(store.scanning ? "Checking status…" : "Retry status. " + (store.statusCheckMessage ?? ""))
                AppearanceMenu(background: $background, cards: $cardPaper, theme: $theme, photoOffset: $photoOffset, photoContext: photoContext)
                Button { changeLayout(.projects) } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 24, height: 24)
                }.buttonStyle(.plain)
                    .help("Open Projects view").accessibilityLabel("Projects view")
            }.font(.system(size: 11)).padding(.horizontal, 12).padding(.bottom, 3)

            ScrollView {
                VStack(spacing: appearance.theme == .photos ? 12 : 8) {
                    ForEach(store.focusCards(in: expanded)) { card in cardContent(card) }
                    if store.focusCards(in: expanded).isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: expanded.symbol).font(.system(size: 24, weight: .ultraLight))
                            Text(store.scanning && store.cards.isEmpty ? "Finding conversations…" : "\(expanded.title) is clear.")
                                .font(appearance.font(12, weight: .medium))
                        }.foregroundStyle(appearance.muted).frame(maxWidth: .infinity).padding(.vertical, 32)
                    }
                }.padding(.horizontal, 10).padding(.top, 4).padding(.bottom, 10)
            }.frame(maxHeight: .infinity).id(expanded)
                .cardDropTarget(enabled: expanded != .running && expanded != .unknown) { move($0, to: expanded) }
        }.padding(.bottom, 6)
            .onChange(of: columns) { _, next in
                if !next.contains(expanded) { expanded = .ready }
            }
    }

    private func columnHeader(_ column: Column) -> some View {
        let open = expanded == column
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) {
                expanded = open ? .ready : column
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: column.symbol).font(.system(size: 11, weight: .medium))
                Text("\(store.count(column))").font(BoardStyle.label(11)).monospacedDigit().fixedSize()
            }.foregroundStyle(open ? (appearance.theme == .brutalist ? appearance.paper : appearance.ink) : appearance.muted)
                .frame(maxWidth: .infinity).frame(height: 29)
                .background(open ? appearance.ink.opacity(appearance.theme == .brutalist ? 1 : 0.13) : Color.clear,
                            in: RoundedRectangle(cornerRadius: appearance.theme == .brutalist ? 0 : 6))
                .overlay(alignment: .bottom) {
                    if open { Rectangle().fill(appearance.accent(column.color)).frame(height: 2) }
                }
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel("\(column.title), \(store.count(column)) conversations")
            .accessibilityValue(open ? "Selected" : "Not selected")
            .help("\(column.title) · \(store.count(column)). Click to show; drag a card here to move it.")
            .cardDropTarget(enabled: column != .running && column != .unknown) { move($0, to: column) }
    }

    private func move(_ id: String, to column: Column) -> Bool {
        guard let card = store.cards.first(where: { $0.id == id }) else { return false }
        if store.column(card) != column { store.mark(card, column) }
        return true
    }
}
