import KanbananaCore
import SwiftUI

// A presentation only: identities, ordering and source state stay on each card.
enum ProjectStackRow: Identifiable {
    case conversation(Conversation)
    case pile(String, [Conversation])
    case heading(String, Int)

    var id: String {
        switch self {
        case .conversation(let card): "card:\(card.id)"
        case .pile(let project, _): "pile:\(project)"
        case .heading(let project, _): "heading:\(project)"
        }
    }
    var conversations: [Conversation] {
        switch self {
        case .conversation(let card): [card]
        case .pile(_, let cards): cards
        case .heading: []
        }
    }
    static func rows(cards: [Conversation], projects: [String: String], stacked: Bool, expanded: Set<String> = [], priorityIDs: Set<String> = []) -> [Self] {
        // Priorities remain individual, clickable cards above any folded piles.
        let priorities = cards.filter { priorityIDs.contains($0.id) }.map(Self.conversation)
        let regular = cards.filter { !priorityIDs.contains($0.id) }
        guard stacked else { return priorities + regular.map(Self.conversation) }
        let groups = Dictionary(grouping: regular.filter { projects[$0.id] != nil }, by: { projects[$0.id]! })
        var emitted = Set<String>()
        return priorities + regular.flatMap { card -> [Self] in
            guard let project = projects[card.id], let group = groups[project], group.count > 1 else { return [.conversation(card)] }
            guard emitted.insert(project).inserted else { return [] }
            if expanded.contains(project) { return [.heading(project, group.count)] + group.map(Self.conversation) }
            return [.pile(project, group)]
        }
    }
}

struct ProjectStackColumn<CardContent: View>: View {
    @Environment(\.boardAppearance) private var appearance
    let store: BoardStore
    let cards: [Conversation]
    let column: Column
    let cardContent: (Conversation) -> CardContent
    @Binding var stacked: Bool
    @Binding var expanded: Set<String>
    @Namespace private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: BoardStore, cards: [Conversation], column: Column, stacked: Binding<Bool>, expanded: Binding<Set<String>>, @ViewBuilder cardContent: @escaping (Conversation) -> CardContent) {
        self.store = store; self.cards = cards; self.column = column; self.cardContent = cardContent
        _stacked = stacked; _expanded = expanded
    }
    private var animation: Animation { reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.24, bounce: 0.12) }
    var body: some View {
        let projects = Dictionary(uniqueKeysWithValues: cards.compactMap { card in store.project(card).map { (card.id, $0.id) } })
        let priorityIDs = Set(cards.filter { store.disposition($0).priority == true }.map(\.id))
        let hasGroups = Dictionary(grouping: projects.filter { !priorityIDs.contains($0.key) }.values, by: { $0 }).values.contains { $0.count > 1 }
        let searching = !store.search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let rows = ProjectStackRow.rows(cards: cards, projects: projects, stacked: stacked && !searching, expanded: expanded, priorityIDs: priorityIDs)
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 5) {
                Image(systemName: column.symbol).font(.system(size: 11, weight: .medium)).foregroundStyle(appearance.accent(column.color))
                Text(column.title).font(appearance.font(11, weight: .semibold)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text("\(cards.count)").font(BoardStyle.label(10)).foregroundStyle(appearance.muted).fixedSize()
                Spacer(minLength: 0)
                if hasGroups || stacked {
                    Button {
                        withAnimation(animation) { stacked.toggle(); expanded.removeAll() }
                    } label: {
                        Image(systemName: stacked ? "rectangle.stack.fill" : "rectangle.stack")
                            .font(.system(size: 11, weight: .medium)).frame(width: 24, height: 23)
                            .foregroundStyle(stacked && !searching ? appearance.ink : appearance.muted)
                            .background(stacked && !searching ? appearance.ink.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(StackPressStyle())
                        .disabled(searching || (!hasGroups && !stacked))
                        .help(searching ? "Search shows individual conversations" : stacked ? "Unstack all projects in \(column.title)" : "Stack conversations by project in \(column.title)")
                        .accessibilityLabel("\(stacked ? "Unstack" : "Stack") projects in \(column.title)")
                        .accessibilityValue(searching ? "Separate cards during search" : stacked ? "Stacked" : "Separate cards")
                }
            }.frame(height: 30).padding(.horizontal, 3)
            ScrollView {
                // Eager layout keeps the small board's card positions available
                // for the folding animation, including cards just off screen.
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(rows) { row in
                        switch row {
                        case .conversation(let card):
                            cardContent(card)
                                .matchedGeometryEffect(id: card.id, in: motion, isSource: true)
                                .transition(.opacity)
                        case .pile(let projectID, let group):
                            if let project = store.saved.projects.first(where: { $0.id == projectID }) {
                                ProjectPile(project: project, cards: group, color: appearance.project(store.projectColor(project)), stripe: appearance.stripe(store.projectColor(project).accent), symbol: store.projectSymbol(project).systemName, motion: motion) {
                                    withAnimation(animation) { _ = expanded.insert(projectID) }
                                }.transition(.opacity)
                            }
                        case .heading(let projectID, let count):
                            if let project = store.saved.projects.first(where: { $0.id == projectID }) {
                                Button {
                                    withAnimation(animation) { _ = expanded.remove(projectID) }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: store.projectSymbol(project).systemName)
                                        Text(project.name).lineLimit(1)
                                        Text("· \(count)").font(BoardStyle.label(9))
                                        Spacer(minLength: 0)
                                        Image(systemName: "rectangle.stack").font(.system(size: 11))
                                    }.font(appearance.font(10, weight: .semibold)).foregroundStyle(appearance.project(store.projectColor(project)).accent)
                                        .padding(.horizontal, 5).frame(height: 23).contentShape(Rectangle())
                                }.buttonStyle(StackPressStyle()).help("Stack \(count) conversations from \(project.name)")
                                    .accessibilityLabel("Restack \(project.name) in \(column.title)")
                                    .transition(.opacity)
                            }
                        }
                    }
                    if cards.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: column == .todo ? "square.dashed" : column == .dealtWith ? "checkmark" : "minus").font(.system(size: 16, weight: .ultraLight))
                            Text(column == .todo ? "Drag a card here for another round." : column == .dealtWith ? "Clear it from your mind." : "All clear for now.").font(appearance.font(9)).multilineTextAlignment(.center)
                        }.foregroundStyle(appearance.muted.opacity(0.75)).frame(maxWidth: .infinity).padding(.vertical, 24)
                    }
                }.frame(maxWidth: .infinity, alignment: .topLeading).padding(.top, 3).padding(.bottom, 10)
            }.id([store.selectedProject ?? "", store.search])
        }.padding(.horizontal, 8).padding(.top, 1)
            .transaction { if reduceMotion { $0.animation = nil } }
            .cardDropTarget(enabled: column != .running) { id in
                guard let card = store.cards.first(where: { $0.id == id }) else { return false }
                if store.column(card) != column { store.mark(card, column) }
                return true
            }
    }
}

private struct ProjectPile: View {
    @Environment(\.boardAppearance) private var appearance
    let project: Project
    let cards: [Conversation]
    let color: ProjectColor
    let stripe: Color
    let symbol: String
    let motion: Namespace.ID
    let spread: () -> Void
    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Button(action: spread) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).frame(width: 22, height: 24)
                        .background(color.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                    Text(project.name).font(appearance.font(12.5, weight: .semibold)).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                }.foregroundStyle(color.accent).padding(10)
                VStack(alignment: .leading, spacing: 7) {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(cards.prefix(2))) { card in
                            Text(card.title).font(appearance.font(11, weight: .medium)).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }.foregroundStyle(appearance.ink)
                    HStack(spacing: 4) {
                        Text("\(cards.count) conversations").font(appearance.font(9, weight: .semibold))
                        Spacer(minLength: 0)
                        ForEach(["claude", "codex"].filter { provider in cards.contains { $0.provider == provider } }, id: \.self) { provider in
                            ProviderIcon(provider: provider, size: 13)
                        }
                    }.foregroundStyle(appearance.muted).padding(.top, 2)
                }.padding(10)
            }.background(appearance.paper)
                .overlay(alignment: .top) { Rectangle().fill(stripe).frame(height: 3).allowsHitTesting(false) }
                .clipShape(RoundedRectangle(cornerRadius: appearance.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: appearance.cornerRadius).strokeBorder(hovering ? appearance.muted.opacity(0.7) : appearance.line, lineWidth: 0.8))
                .shadow(color: appearance.ink.opacity(hovering ? 0.13 : 0.06), radius: hovering ? 5 : 2, x: 0, y: 2)
                .matchedGeometryEffect(id: cards[0].id, in: motion)
                .background {
                    ForEach(Array(cards.prefix(3).enumerated().dropFirst().reversed()), id: \.element.id) { index, card in
                        RoundedRectangle(cornerRadius: appearance.cornerRadius).fill(appearance.paper)
                            .overlay(RoundedRectangle(cornerRadius: appearance.cornerRadius).strokeBorder(appearance.line, lineWidth: 0.8))
                            .matchedGeometryEffect(id: card.id, in: motion)
                            .padding(.horizontal, CGFloat(index * 3))
                            .rotationEffect(.degrees(reduceMotion ? 0 : (index == 1 ? -1.5 : 1.5)), anchor: .bottom)
                            .offset(y: CGFloat(index * 5))
                            .allowsHitTesting(false).accessibilityHidden(true)
                    }
                }
                .offset(y: hovering && !reduceMotion ? -2 : 0)
                .padding(.bottom, cards.count > 2 ? 11 : 6)
                .contentShape(Rectangle())
        }.buttonStyle(StackPressStyle()).help("Spread \(cards.count) conversations from \(project.name)")
            .accessibilityLabel("Spread \(project.name) stack, \(cards.count) conversations")
            .onHover { value in withAnimation(.easeOut(duration: 0.12)) { hovering = value } }
    }
}

private struct StackPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
