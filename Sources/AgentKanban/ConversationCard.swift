import KanbananaCore
import SwiftUI
import UniformTypeIdentifiers

struct ConversationCard: View, Equatable {
    @Environment(\.boardAppearance) private var appearance
    let store: BoardStore
    nonisolated let presentation: CardPresentation
    var card: Conversation { presentation.card }
    var project: Project? { presentation.project }
    var projects: [Project] { presentation.projects }
    var disposition: Disposition { presentation.disposition }
    var displayedColumn: Column { presentation.displayedColumn }
    var latestSummary: String? { presentation.latestSummary }
    var compact: Bool { presentation.compact }
    var opensProjectBoard: Bool { presentation.opensProjectBoard }
    let showProject: ((String) -> Void)?
    let showHistory: () -> Void

    init(store: BoardStore, card: Conversation, project: Project?, projects: [Project], disposition: Disposition,
         displayedColumn: Column, latestSummary: String?, compact: Bool = false, opensProjectBoard: Bool = false,
         showProject: ((String) -> Void)? = nil, showHistory: @escaping () -> Void) {
        self.store = store
        self.presentation = CardPresentation(owner: ObjectIdentifier(store), card: card, project: project, projects: projects,
            disposition: disposition, displayedColumn: displayedColumn, latestSummary: latestSummary,
            compact: compact, opensProjectBoard: opensProjectBoard)
        self.showProject = showProject
        self.showHistory = showHistory
    }
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.presentation == rhs.presentation }
    @State private var hovering = false
    @State private var projectHovering = false
    @State private var detailsExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let color = appearance.project(store.projectColor(project))
        let headingAccent = appearance.theme == .brutalist ? Color.white : color.accent
        let foldsDetails = (displayedColumn == .dealtWith || displayedColumn == .todo) && !disposition.parked
        let collapsed = foldsDetails && !detailsExpanded
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                CardDragHandle(id: card.id, title: card.title, color: headingAccent, symbol: compact ? nil : store.projectSymbol(project).systemName).frame(width: compact ? 12 : 22, height: 24)
                if compact {
                    Button { store.open(card) } label: {
                        Text(card.title).font(appearance.font(12, weight: .semibold)).tracking(-0.1).lineLimit(2).foregroundStyle(appearance.theme == .brutalist ? .white : appearance.ink).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).help("Open \(card.title) in \(card.providerName)").layoutPriority(1)
                        .onDrag { NSItemProvider(object: card.id as NSString) } preview: {
                            Text(card.title).font(appearance.font(12, weight: .semibold)).lineLimit(1).padding(10).frame(width: 200).background(color.wash, in: RoundedRectangle(cornerRadius: 8))
                        }
                } else if let project {
                    Button { if let showProject { showProject(project.id) } else { store.selectProject(project.id) } } label: {
                        Text(project.name).font(appearance.font(12.5, weight: .semibold)).tracking(-0.2).underline(projectHovering).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).foregroundStyle(headingAccent)
                        .help("\(card.title)\nShow \(project.name)\(opensProjectBoard ? " in the full board" : "")").accessibilityLabel("Show project \(project.name)")
                        .onHover { projectHovering = $0 }.layoutPriority(1)
                } else {
                    Text("Ungrouped").font(appearance.font(12.5, weight: .semibold)).foregroundStyle(headingAccent).frame(maxWidth: .infinity, alignment: .leading)
                }
                priorityButton
                if foldsDetails {
                    Button { withAnimation(.easeOut(duration: 0.14)) { detailsExpanded.toggle() } } label: {
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)).rotationEffect(.degrees(detailsExpanded ? 180 : 0)).frame(width: 18, height: 24).contentShape(Rectangle())
                            .overlay(alignment: .bottomTrailing) {
                                if disposition.todoNote != nil { Circle().fill(color.accent).frame(width: 3, height: 3).padding(2) }
                            }
                    }.buttonStyle(.plain).foregroundStyle(headingAccent)
                        .help("\(detailsExpanded ? "Collapse" : "Expand") \(card.title)" + (disposition.todoNote.map { "\nTo do: \($0)" } ?? ""))
                        .accessibilityLabel("\(detailsExpanded ? "Collapse" : "Expand") \(displayedColumn == .todo ? "To do" : "dealt-with") card: \(card.title)")
                        .accessibilityValue(detailsExpanded ? "Expanded" : "Collapsed")
                }
            }.padding(.horizontal, compact ? 8 : 10)
                .padding(.top, compact ? 6 : 8).padding(.bottom, compact ? 6 : 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(appearance.theme == .brutalist ? Color.black : Color.clear)
                .padding(.bottom, appearance.theme == .brutalist ? (compact ? 8 : 4) : 0)
            if !compact || !collapsed {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .bottom, spacing: 6) {
                        Button { store.open(card) } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                if !compact {
                                    HStack(spacing: 5) {
                                        if collapsed { ProviderIcon(provider: card.provider, size: 15) }
                                        Text(card.title).font(appearance.font(12, weight: .semibold)).tracking(-0.1).lineSpacing(1).lineLimit(2).foregroundStyle(appearance.ink).frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                if !collapsed {
                                    if let r = card.requests.last {
                                        Text(latestSummary ?? String(r.text.prefix(220))).font(appearance.font(11)).lineSpacing(1).lineLimit(3).foregroundStyle(appearance.ink.opacity(0.76))
                                    } else { Text("Request history unavailable").font(appearance.font(10)).foregroundStyle(appearance.muted) }
                                }
                            }.contentShape(Rectangle())
                        }.buttonStyle(.plain).padding(.top, compact ? 5 : collapsed ? 2 : 5).help("Open \(card.title) in \(card.providerName)")
                            .onDrag { NSItemProvider(object: card.id as NSString) } preview: {
                                Text(card.title).font(appearance.font(12, weight: .semibold)).lineLimit(1).padding(10).frame(width: 200).background(color.wash, in: RoundedRectangle(cornerRadius: 8))
                            }
                        if collapsed { dealtWithButton }
                    }
                    if !collapsed {
                        if displayedColumn == .todo || disposition.todoNote != nil {
                            HStack(alignment: .top, spacing: 4) {
                                Button { store.todoNoteCard = card } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 4) {
                                            Text("TO DO NOTE").tracking(0.6)
                                            Spacer(minLength: 0)
                                            Image(systemName: "pencil")
                                        }.font(BoardStyle.label(8)).foregroundStyle(appearance.muted)
                                        Text(disposition.todoNote ?? "Add a note for the next round…").font(appearance.font(11)).foregroundStyle(appearance.ink).lineLimit(4).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).help(disposition.todoNote ?? "Add an optional To do note")
                                    .accessibilityLabel("Edit To do note for \(card.title)")
                                if disposition.todoNote != nil {
                                    Button {
                                        withAnimation(.easeOut(duration: 0.14)) { store.setTodoNote(card.id, "") }
                                    } label: {
                                        Image(systemName: "trash").font(.system(size: 10)).frame(width: 22, height: 22).contentShape(Rectangle())
                                    }.buttonStyle(.plain).foregroundStyle(appearance.muted)
                                        .help("Delete To do note").accessibilityLabel("Delete To do note for \(card.title)")
                                }
                            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                .background(appearance.ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 6)).padding(.top, 8)
                        }
                        if displayedColumn == .needsMe || displayedColumn == .unknown || card.observationIssue != nil {
                            HStack(spacing: 4) {
                                Image(systemName: displayedColumn == .needsMe ? "exclamationmark.circle.fill" : "questionmark.circle")
                                Text(card.observationIssue == nil ? card.reason : "Updates paused").lineLimit(1)
                            }.font(appearance.font(9, weight: .medium)).foregroundStyle(appearance.ink.opacity(0.8)).padding(.horizontal, 6).padding(.vertical, 4)
                                .background(appearance.ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 5)).padding(.top, 9)
                                .help(card.observationIssue.map { "\($0). Last observed state: \(card.state.title)." } ?? card.reason)
                        }
                        Rectangle().fill(appearance.line).frame(height: 0.6).padding(.top, compact ? 6 : 11).padding(.bottom, 6)
                        HStack(spacing: 6) {
                            providerButton
                            Text(activityLabel(card.updated)).font(BoardStyle.label(8)).foregroundStyle(appearance.muted).lineLimit(1)
                            if !card.requests.isEmpty && latestSummary == nil { Text("excerpt").font(appearance.font(8)).foregroundStyle(appearance.muted) }
                            Spacer(minLength: 0)
                            Button(action: showHistory) { Image(systemName: "text.alignleft").font(.system(size: 11)) }.buttonStyle(.plain).help("Expand request history").accessibilityLabel("Request history for \(card.title)")
                            Menu { actions } label: { Image(systemName: "ellipsis").font(.system(size: 11)) }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Conversation actions").accessibilityLabel("Actions for \(card.title)")
                            dealtWithButton
                        }.foregroundStyle(appearance.muted)
                        if disposition.parked {
                            Button { store.park(card, false) } label: { Label("Restore to board", systemImage: "arrow.uturn.backward").font(appearance.font(10, weight: .medium)) }.buttonStyle(.plain).foregroundStyle(appearance.ink).padding(.top, 9)
                        }
                    }
                }.padding(.horizontal, compact ? 8 : 10).padding(.bottom, compact ? 2 : collapsed ? 8 : 11)
            }
            if compact && collapsed {
                HStack { providerButton; Spacer(minLength: 0); dealtWithButton }
                    .padding(.horizontal, 8).padding(.bottom, 2)
            }
        }.background(appearance.paper)
            .overlay(alignment: .top) { Rectangle().fill(appearance.stripe(store.projectColor(project).accent)).frame(height: 3).allowsHitTesting(false) }
            .clipShape(RoundedRectangle(cornerRadius: appearance.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: appearance.cornerRadius).strokeBorder(hovering ? appearance.muted.opacity(0.55) : appearance.line, lineWidth: appearance.borderWidth))
            .shadow(color: appearance.shadow, radius: appearance.theme == .brutalist ? 0 : (hovering ? 6 : 3), x: appearance.theme == .brutalist ? 3 : 0, y: appearance.theme == .brutalist ? 3 : 2)
            .contextMenu { actions }
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.14), value: hovering)
            .onChange(of: displayedColumn) { _, _ in detailsExpanded = false }
    }
    private var priorityButton: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { store.togglePriority(card.id) }
        } label: {
            Image(systemName: disposition.priority == true ? "star.fill" : "star")
                .font(.system(size: 11, weight: .medium)).frame(width: 20, height: compact ? 20 : 24).contentShape(Rectangle())
                .foregroundStyle(disposition.priority == true ? appearance.accent(Color(hex: 0xA36900)) : (appearance.theme == .brutalist ? .white : appearance.muted))
        }.buttonStyle(.plain)
            .help(disposition.priority == true ? "Remove priority" : "Make priority — keep at the top of lists")
            .accessibilityLabel("\(disposition.priority == true ? "Remove priority from" : "Make priority:") \(card.title)")
            .accessibilityValue(disposition.priority == true ? "Priority" : "Not priority")
    }
    private var dealtWithButton: some View {
        let isDealtWith = displayedColumn == .dealtWith && !disposition.parked
        return Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                store.mark(card, .dealtWith)
                if disposition.parked { store.park(card, false) }
            }
        } label: {
            Image(systemName: isDealtWith ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 13, weight: .medium)).frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(appearance.muted)
            .disabled(isDealtWith)
            .help(isDealtWith ? "Already dealt with" : "Move to Dealt with")
            .accessibilityLabel("\(isDealtWith ? "Already dealt with:" : "Move to Dealt with:") \(card.title)")
    }
    private var providerButton: some View {
        Button { store.open(card) } label: { ProviderIcon(provider: card.provider, size: 15).frame(width: 20, height: 20).contentShape(Rectangle()) }
            .buttonStyle(.plain).help("Open \(card.title) in \(card.providerName)").accessibilityLabel("Open \(card.title) in \(card.providerName)")
    }
    @ViewBuilder private var actions: some View {
        Button("Open in \(card.providerName)") { store.open(card) }
        Button("Request history", action: showHistory)
        Divider()
        if displayedColumn != .todo { Button("Move to To do") { store.mark(card, .todo) } }
        if displayedColumn == .todo || disposition.todoNote != nil {
            Button(disposition.todoNote == nil ? "Add To do note…" : "Edit To do note…") { store.todoNoteCard = card }
        }
        Button("Mark dealt with") { store.mark(card, .dealtWith) }
        Button(disposition.parked ? "Restore to board" : "Move to parking lot") { store.park(card, !disposition.parked) }
        Menu("Move to project") { ForEach(projects) { p in Button(p.name) { store.assign(card, to: p.id) } } }
        Menu("Correct response status") {
            Button("Needs me") { store.mark(card, .needsMe) }
            Button("Ready to check") { store.mark(card, .ready) }
        }
    }
}


/// Equality is a pure comparison of Sendable values, independent of the view's actor.
struct CardPresentation: Equatable, Sendable {
    let owner: ObjectIdentifier
    let card: Conversation
    let project: Project?
    let projects: [Project]
    let disposition: Disposition
    let displayedColumn: Column
    let latestSummary: String?
    let compact: Bool
    let opensProjectBoard: Bool
}
