import KanbananaCore
import SwiftUI

struct ProjectLane: Identifiable {
    let project: Project?
    let cards: [Conversation]
    let latestActivity: Double
    let hasPriority: Bool
    var id: String { project.map { "project:\($0.id)" } ?? "ungrouped" }
    var name: String { project?.name ?? "Ungrouped" }

    static func make(visible: [Conversation], allCards: [Conversation], projects: [Project], dispositions: [String: Disposition]) -> [Self] {
        let known = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        func projectID(_ card: Conversation) -> String? {
            guard let id = dispositions[card.id]?.projectID, known[id] != nil else { return nil }
            return id
        }
        let activity = Dictionary(grouping: allCards.filter { dispositions[$0.id]?.parked != true }, by: projectID)
            .mapValues { $0.map(\.updated).max() ?? 0 }
        return Dictionary(grouping: visible, by: projectID).map { id, cards in
            Self(project: id.flatMap { known[$0] }, cards: CardOrder.sorted(cards, dispositions: dispositions), latestActivity: activity[id] ?? cards.map(\.updated).max() ?? 0, hasPriority: cards.contains { dispositions[$0.id]?.priority == true })
        }.sorted {
            if $0.hasPriority != $1.hasPriority { return $0.hasPriority }
            if $0.latestActivity != $1.latestActivity { return $0.latestActivity > $1.latestActivity }
            if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            return $0.id < $1.id
        }
    }
}

extension BoardStore {
    // A lane cell identifies both the project and status. Same-cell drops do
    // nothing; source-owned Running/Unknown states cannot be manufactured.
    @discardableResult func moveToLane(_ card: Conversation, projectID: String?, column destination: Column) -> Bool {
        guard destination != .running && destination != .unknown,
              projectID == nil || saved.projects.contains(where: { $0.id == projectID }) else { return false }
        if let projectID, disposition(card).projectID != projectID { assign(card, to: projectID) }
        else if projectID == nil && project(card) != nil { return false }
        if column(card) != destination { mark(card, destination) }
        return true
    }
}

struct ProjectSwimlanes<CardContent: View>: View {
    @Environment(\.boardAppearance) private var appearance
    let store: BoardStore
    @Binding var collapsed: Set<String>
    let cardContent: (Conversation) -> CardContent
    @Namespace private var scrollSpace
    @State private var headerFrames: [String: CGRect] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let lanes = ProjectLane.make(visible: store.visible, allCards: store.cards, projects: store.saved.projects, dispositions: store.saved.dispositions)
        VStack(spacing: 7) {
            HStack(spacing: 0) {
                ForEach(Array(Column.board.enumerated()), id: \.element) { index, column in
                    if index > 0 { Color.clear.frame(width: 1) }
                    HStack(spacing: 6) {
                        Image(systemName: column.symbol).foregroundStyle(appearance.accent(column.color))
                        Text(column.title).font(appearance.font(11, weight: .semibold)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                        Text("\(store.visible.filter { store.column($0) == column }.count)").font(BoardStyle.label(9)).foregroundStyle(appearance.muted).fixedSize()
                        Spacer(minLength: 0)
                    }.font(.system(size: 11)).padding(.horizontal, 11).frame(maxWidth: .infinity)
                }
            }.frame(height: 30).padding(.horizontal, 9)
            ScrollView {
                // The small board does not need estimated lazy section sizes.
                // Reordering/collapsing pinned lazy sections caused an unbounded
                // layout transaction on macOS. Use actual lane sizes instead.
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(lanes) { lane in
                        laneHeader(lane).background {
                            GeometryReader { geometry in
                                Color.clear.preference(key: LaneHeaderFrames.self, value: [lane.id: geometry.frame(in: .named(scrollSpace))])
                            }
                        }
                        if !collapsed.contains(lane.id) || !store.search.isEmpty {
                            laneCards(lane).padding(.bottom, 6)
                        } else { Color.clear.frame(height: 6) }
                    }
                }.padding(.horizontal, 9).padding(.bottom, 6)
            }
            .coordinateSpace(name: scrollSpace)
            .onPreferenceChange(LaneHeaderFrames.self) { frames in
                if headerFrames != frames { headerFrames = frames }
            }
            .overlay(alignment: .top) {
                if let pinned = PinnedLaneHeader.resolve(order: lanes.map(\.id), frames: headerFrames),
                   let lane = lanes.first(where: { $0.id == pinned.id }) {
                    laneHeader(lane).frame(width: headerFrames[pinned.id]?.width)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 9).offset(y: pinned.offset)
                }
            }.clipped().id([store.selectedProject ?? "", store.search])
        }
    }
    private func laneHeader(_ lane: ProjectLane) -> some View {
        let color = appearance.project(store.projectColor(lane.project))
        let folded = collapsed.contains(lane.id) && store.search.isEmpty
        return HStack(spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                    if folded { collapsed.remove(lane.id) } else { collapsed.insert(lane.id) }
                }
            } label: {
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).rotationEffect(.degrees(folded ? 0 : 90)).frame(width: 18, height: 24).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(!store.search.isEmpty)
                .help("\(folded ? "Expand" : "Collapse") \(lane.name)")
                .accessibilityLabel("\(folded ? "Expand" : "Collapse") project lane \(lane.name)")
            Image(systemName: store.projectSymbol(lane.project).systemName).font(.system(size: 16, weight: .semibold)).frame(width: 25)
            if lane.hasPriority {
                Image(systemName: "star.fill").font(.system(size: 10)).help("Contains priority cards").accessibilityLabel("Contains priority cards")
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(lane.name).font(appearance.font(13.5, weight: .semibold)).lineLimit(1)
                    Text("\(lane.cards.count) \(lane.cards.count == 1 ? "conversation" : "conversations")").font(appearance.font(9, weight: .medium)).foregroundStyle(appearance.muted).fixedSize()
                }
                if let note = lane.project?.note, !note.isEmpty {
                    Text(note).font(appearance.font(10)).foregroundStyle(appearance.ink.opacity(0.78)).lineLimit(1).help(note)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
            Text("Active \(activityLabel(lane.latestActivity))").font(BoardStyle.label(8)).foregroundStyle(appearance.muted).frame(minWidth: 88, alignment: .trailing)
        }.foregroundStyle(color.accent).padding(.horizontal, 8).padding(.vertical, 4)
            .background(appearance.paper)
            .overlay(alignment: .top) { Rectangle().fill(appearance.stripe(store.projectColor(lane.project).accent)).frame(height: 3).allowsHitTesting(false) }
            .overlay(alignment: .bottom) { Rectangle().fill(appearance.line).frame(height: 0.7).allowsHitTesting(false) }
            .clipShape(RoundedRectangle(cornerRadius: appearance.theme == .brutalist ? 0 : 7))
            .cardDropTarget(enabled: lane.project != nil) { id in
                guard let project = lane.project, let card = store.cards.first(where: { $0.id == id }) else { return false }
                if store.disposition(card).projectID != project.id { store.assign(card, to: project.id) }
                return true
            }
    }
    private func laneCards(_ lane: ProjectLane) -> some View {
        let unavailable = lane.cards.filter { store.column($0) == .unknown }
        return VStack(alignment: .leading, spacing: 0) {
            if !unavailable.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Status unavailable · \(unavailable.count)", systemImage: "questionmark.circle").font(appearance.font(9, weight: .medium)).foregroundStyle(appearance.muted)
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 8) { ForEach(unavailable) { cardContent($0).frame(width: 180) } }.padding(.bottom, 3)
                    }
                }.padding(.horizontal, 8).padding(.top, 8)
            }
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(Column.board.enumerated()), id: \.element) { index, column in
                    if index > 0 { Rectangle().fill(appearance.line.opacity(0.55)).frame(width: 1) }
                    let cards = lane.cards.filter { store.column($0) == column }
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(cards) { cardContent($0) }
                        if cards.isEmpty {
                            Text("—").font(appearance.font(12)).foregroundStyle(appearance.muted.opacity(0.35)).frame(maxWidth: .infinity).padding(.top, 7).accessibilityHidden(true)
                        }
                    }.padding(.horizontal, 8).padding(.top, 5).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top).frame(minHeight: 52)
                        .cardDropTarget(enabled: column != .running) { id in
                            guard let card = store.cards.first(where: { $0.id == id }) else { return false }
                            return store.moveToLane(card, projectID: lane.project?.id, column: column)
                        }
                }
            }.fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct LaneHeaderFrames: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct PinnedLaneHeader: Equatable {
    let id: String
    let offset: CGFloat
    static func resolve(order: [String], frames: [String: CGRect]) -> Self? {
        guard let index = order.lastIndex(where: { frames[$0].map { $0.minY < 0 && $0.height > 0 } == true }),
              let current = frames[order[index]] else { return nil }
        let nextY = order.dropFirst(index + 1).compactMap { frames[$0]?.minY }.first
        return Self(id: order[index], offset: nextY.map { min(0, $0 - current.height) } ?? 0)
    }
}
