import SwiftUI
import UniformTypeIdentifiers

extension Column {
    var color: Color { switch self { case .todo: Color(hex: 0x896200); case .running: Color(hex: 0x527B9A); case .needsMe: Color(hex: 0xAD653B); case .ready: Color(hex: 0x47735A); case .dealtWith: BoardStyle.muted; case .unknown: BoardStyle.muted } }
}
struct BoardView: View {
    @ObservedObject var store: BoardStore
    @State private var stackedColumns: Set<Column>
    @State private var expandedStacks: [Column: Set<String>] = [:]
    @State private var collapsedLanes = Set<String>()
    @AppStorage private var layout: BoardLayout
    @AppStorage private var background: BoardBackground
    @AppStorage private var cardPaper: CardPaper
    @AppStorage private var theme: BoardTheme
    @AppStorage private var photoOffset: Int
    @State private var detail: Conversation?
    @State private var settings = false
    @State private var projects = false
    @State private var unavailableExpanded = true
    @FocusState private var searchFocused: Bool
    private let layoutChanged: (BoardLayout) -> Void
    private let appearanceChanged: (BoardAppearance) -> Void
    private var appearance: BoardAppearance { .init(background: background, cards: cardPaper, theme: theme) }
    private var photoContext: String {
        store.saved.projects.filter { p in store.cards.contains { !store.disposition($0).parked && store.disposition($0).projectID == p.id } }.map(\.name).joined(separator: " ")
    }
    init(store: BoardStore, initiallyStacked: Bool = false, layoutPreferences: UserDefaults = .standard, layoutChanged: @escaping (BoardLayout) -> Void = { _ in }, appearanceChanged: @escaping (BoardAppearance) -> Void = { _ in }) {
        self.store = store
        self.layoutChanged = layoutChanged
        self.appearanceChanged = appearanceChanged
        _stackedColumns = State(initialValue: initiallyStacked ? Set(Column.board) : [])
        _layout = AppStorage(wrappedValue: .columns, "boardLayout", store: layoutPreferences)
        _background = AppStorage(wrappedValue: .brightYellow, BoardBackground.preferenceKey, store: layoutPreferences)
        _cardPaper = AppStorage(wrappedValue: .cream, CardPaper.preferenceKey, store: layoutPreferences)
        _theme = AppStorage(wrappedValue: .classic, BoardTheme.preferenceKey, store: layoutPreferences)
        _photoOffset = AppStorage(wrappedValue: 0, "photoOffset", store: layoutPreferences)
    }
    var body: some View {
        Group {
            if layout == .focus {
                FocusBoard(store: store, background: $background, cardPaper: $cardPaper, theme: $theme, photoOffset: $photoOffset, photoContext: photoContext, changeLayout: { store.parking = false; layout = $0 }) { card in
                    cardView(card, opensProjectBoard: true)
                }
            } else { fullBoard }
        }
        .frame(minWidth: layout.minimumSize.width, maxWidth: .infinity, minHeight: layout.minimumSize.height, maxHeight: .infinity)
        .background { BoardBackdrop(appearance: appearance, photoOffset: photoOffset, context: photoContext) }
        .ignoresSafeArea(.container, edges: .top)
        .foregroundStyle(appearance.ink)
        .tint(appearance.ink)
        .environment(\.colorScheme, appearance.scheme)
        .onChange(of: layout) { _, next in layoutChanged(next) }
        .onChange(of: appearance) { _, next in appearanceChanged(next) }
        .onAppear { appearanceChanged(appearance) }
        .sheet(isPresented: $store.needsOnboarding) { WelcomeView(store: store).interactiveDismissDisabled().preferredColorScheme(appearance.scheme) }
        .sheet(item: $detail) { c in HistoryView(store: store, cardID: c.id).preferredColorScheme(appearance.scheme) }
        .sheet(isPresented: $settings) { SettingsView(store: store).preferredColorScheme(appearance.scheme) }
        .sheet(isPresented: $projects) { ProjectsView(store: store).preferredColorScheme(appearance.scheme) }
        .sheet(item: $store.todoNoteCard) { c in TodoNoteView(store: store, card: c).preferredColorScheme(appearance.scheme) }
        .environment(\.boardAppearance, appearance)
    }
    private var fullBoard: some View {
        VStack(spacing: 0) {
            header
            projectStrip
            if let id = store.selectedProject, let p = store.saved.projects.first(where: { $0.id == id }) {
                projectNote(p)
            }
            if let message = store.error ?? store.readerError {
                HStack { Text(message).font(appearance.font(11)); Spacer(); Button("Dismiss") { store.error = nil; store.readerError = nil } }.padding(10).background(.orange.opacity(0.1))
            }
            let unavailable = store.visible.filter { store.column($0) == .unknown }.count
            if !store.sourceWarnings.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath").padding(.top, 2)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(store.sourceWarnings, id: \.self) { Text($0).font(appearance.font(11, weight: .medium)) }
                        Text("Showing last known states\(unavailable > 0 ? " · \(unavailable) unavailable" : ""). Retrying automatically.").font(appearance.font(10))
                    }
                    Spacer(minLength: 4)
                    StatusRetryButton(store: store)
                }.foregroundStyle(appearance.muted).padding(.horizontal, 18).padding(.bottom, 8)
            }
            if unavailable > 0 && store.sourceWarnings.isEmpty {
                HStack {
                    Label("\(unavailable) \(unavailable == 1 ? "status" : "statuses") unavailable", systemImage: "questionmark.circle").font(appearance.font(11, weight: .medium))
                    Spacer()
                    StatusRetryButton(store: store)
                }.foregroundStyle(appearance.muted).padding(.horizontal, 18).padding(.bottom, 8)
            }
            if store.scanning && store.cards.isEmpty {
                Spacer(); ProgressView("Finding your conversations…"); Spacer()
            } else if store.visible.isEmpty {
                Spacer()
                Image(systemName: store.parking ? "archivebox" : "rectangle.3.group").font(.system(size: 30, weight: .ultraLight)).foregroundStyle(appearance.muted)
                Text(store.parking ? "Room to breathe." : "A clear view.").font(appearance.font(20, weight: .semibold)).padding(.top, 8)
                Text("No conversations here. Try another project or search.").font(appearance.font(11)).foregroundStyle(appearance.muted)
                Spacer()
            } else {
                if layout == .columns && store.visible.contains(where: { store.column($0) == .unknown }) && !store.parking {
                    DisclosureGroup(isExpanded: $unavailableExpanded) {
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(store.visible.filter { store.column($0) == .unknown }) { card in cardView(card).frame(width: 190) }
                            }.padding(.vertical, 4)
                        }.frame(maxHeight: 180)
                    } label: {
                        Label("Status unavailable · \(store.visible.filter { store.column($0) == .unknown }.count)", systemImage: "questionmark.circle").font(appearance.font(11)).foregroundStyle(appearance.muted)
                    }.padding(.horizontal, 18).padding(.bottom, 10)
                }
                if store.parking {
                    ScrollView {
                        ParkingGrid {
                            ForEach(store.visible) { card in cardView(card) }
                        }.padding(16)
                    }
                } else if layout == .projects {
                    ProjectSwimlanes(store: store, collapsed: $collapsedLanes) { cardView($0, compact: true) }
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(Column.board.enumerated()), id: \.element) { index, col in
                            if index > 0 { Rectangle().fill(appearance.line.opacity(0.65)).frame(width: 1).padding(.top, 3).padding(.bottom, 12) }
                            columnView(col).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        }
                    }.padding(.horizontal, 9).padding(.bottom, 6)
                }
            }
            Rectangle().fill(appearance.line).frame(height: 1)
            footer
        }
    }
    private var header: some View {
        HStack(spacing: 9) {
            BananaMark().frame(width: 24, height: 25)
            Text("kanbanana").font(appearance.font(15, weight: .semibold)).tracking(-0.25).foregroundStyle(appearance.ink)
            Picker("Board view", selection: $layout) {
                ForEach(BoardLayout.allCases.filter { $0 != .focus }, id: \.self) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).labelsHidden().controlSize(.small).frame(width: 165).accessibilityLabel("Board view")
                .help("Switch between status columns and project swimlanes")
            Button { layout = .focus } label: {
                Image(systemName: "rectangle.portrait").font(.system(size: 13))
            }.buttonStyle(QuietIconButton()).help("Focus view — a narrow strip with Ready to check open").accessibilityLabel("Focus view")
            Spacer(minLength: 10)
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 11))
                ZStack(alignment: .leading) {
                    if store.search.isEmpty {
                        Text("Find a conversation").foregroundStyle(appearance.muted).allowsHitTesting(false).accessibilityHidden(true)
                    }
                    TextField("", text: $store.search).textFieldStyle(.plain).foregroundStyle(appearance.ink).accessibilityLabel("Find a conversation").focused($searchFocused)
                }.font(appearance.font(11))
                if !store.search.isEmpty {
                    Button { store.search = ""; searchFocused = true } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 12)).frame(width: 18, height: 22).contentShape(Rectangle())
                    }.buttonStyle(.plain).help("Clear search").accessibilityLabel("Clear search")
                }
            }.padding(.horizontal, 10).frame(width: 153, height: 28).background(appearance.paper, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(appearance.line, lineWidth: 0.7)).foregroundStyle(appearance.muted)
            Button { store.parking.toggle() } label: {
                HStack(spacing: 6) { Image(systemName: "archivebox"); Text("\(store.parkedCount)").font(BoardStyle.label(10)) }
                    .foregroundStyle(store.parking ? ProjectColor.palette[4].accent : appearance.muted).padding(.horizontal, 10).frame(height: 28)
                    .background(store.parking ? appearance.project(ProjectColor.palette[4]).wash : appearance.ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 7))
            }.buttonStyle(.plain).help("Parking lot").accessibilityLabel("Parking lot")
                .cardDropTarget { id in
                    guard let card = store.cards.first(where: { $0.id == id }) else { return false }
                    store.park(card, true); return true
                }
            AppearanceMenu(background: $background, cards: $cardPaper, theme: $theme, photoOffset: $photoOffset, photoContext: photoContext)
            Button { settings = true } label: { Image(systemName: "gearshape").font(.system(size: 13)) }.buttonStyle(QuietIconButton()).help("Settings").accessibilityLabel("Settings")
        }.padding(.horizontal, 18).padding(.vertical, 7).padding(.top, 23)
            .background(appearance.canvas)
    }
    private var projectStrip: some View {
        HStack(spacing: 10) {
            chip("All projects", project: nil)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(store.saved.projects) { p in
                        chip(p.name, project: p)
                            .cardDropTarget { id in
                                guard let c = store.cards.first(where: { $0.id == id }) else { return false }
                                store.assign(c, to: p.id); return true
                            }
                    }
                }
            }
            Button { projects = true } label: { Image(systemName: "slider.horizontal.3").font(.system(size: 12)) }
                .buttonStyle(QuietIconButton()).help("Manage projects, notes and colors").accessibilityLabel("Manage projects")
        }.padding(.horizontal, 18).padding(.top, 3).padding(.bottom, 13)
    }
    private func chip(_ text: String, project: Project?) -> some View {
        let selected = store.selectedProject == project?.id
        let color = appearance.project(store.projectColor(project))
        return Button { store.selectProject(project?.id) } label: {
            HStack(spacing: 5) {
                if project != nil { Image(systemName: store.projectSymbol(project).systemName).font(.system(size: 12, weight: .semibold)).foregroundStyle(color.accent).frame(width: 16).accessibilityHidden(true) }
                else { Image(systemName: "square.grid.2x2.fill").font(.system(size: 9)) }
                Text(text).font(appearance.font(11.5, weight: .semibold)).lineLimit(1)
            }.padding(.horizontal, 10).frame(height: 30)
                .foregroundStyle(project == nil && selected ? appearance.paper : appearance.ink)
                .background(project == nil && selected ? appearance.ink : selected ? color.wash : appearance.paper.opacity(0.8), in: Capsule())
                .overlay(Capsule().strokeBorder(selected && project != nil ? color.accent.opacity(0.65) : appearance.line.opacity(0.8), lineWidth: selected && project != nil ? 1.2 : 0.7))
        }.buttonStyle(.plain).help(project == nil ? "Show all projects and clear search" : "Show only \(text)")
    }
    private func projectNote(_ p: Project) -> some View {
        let color = appearance.project(store.projectColor(p))
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "pin.fill").font(.system(size: 11)).rotationEffect(.degrees(-25)).foregroundStyle(color.accent).padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                Text("NEAR-TERM GOAL").font(BoardStyle.label(8)).tracking(1.1).foregroundStyle(color.accent)
                TextField("What would move this project forward?", text: Binding(get: { store.saved.projects.first(where: { $0.id == p.id })?.note ?? "" }, set: { store.setNote(p.id, $0) }), axis: .vertical)
                    .lineLimit(1...2).textFieldStyle(.plain).font(appearance.font(12, weight: .medium))
            }
            Spacer(minLength: 0)
        }.padding(12).background(color.wash, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.edge, lineWidth: 0.7))
            .padding(.horizontal, 18).padding(.bottom, 13)
    }
    private func columnView(_ col: Column) -> some View {
        let cards = store.visible.filter { store.column($0) == col }
        return ProjectStackColumn(store: store, cards: cards, column: col,
            stacked: Binding(get: { stackedColumns.contains(col) }, set: { value in
                if value { stackedColumns.insert(col) } else { stackedColumns.remove(col) }
            }),
            expanded: Binding(get: { expandedStacks[col] ?? [] }, set: { expandedStacks[col] = $0 })
        ) { cardView($0) }
    }
    private func cardView(_ card: Conversation, compact: Bool = false, opensProjectBoard: Bool = false) -> some View {
        ConversationCard(store: store, card: card, project: store.project(card), projects: store.saved.projects, disposition: store.disposition(card), displayedColumn: store.column(card), latestSummary: card.requests.last.flatMap { store.summary(card, $0) }, compact: compact, opensProjectBoard: opensProjectBoard, showProject: { id in
            store.selectProject(id)
            if opensProjectBoard { store.parking = false; layout = .projects }
        }, showHistory: { detail = card }).equatable()
    }
    private var footer: some View {
        HStack(spacing: 7) {
            ForEach(["claude", "codex"], id: \.self) { provider in
                let captured = store.cards.filter { $0.provider == provider }.count
                let shown = store.visible.filter { $0.provider == provider }.count
                HStack(spacing: 4) {
                    ProviderIcon(provider: provider, size: 15)
                    .overlay(alignment: .bottomTrailing) {
                        Circle().fill(store.health[provider]?.hasPrefix("Connected") == true ? Color(hex: 0x5C8165) : .orange).frame(width: 4, height: 4).overlay(Circle().stroke(appearance.canvas, lineWidth: 1))
                    }
                    Text("\(shown)/\(captured)").font(BoardStyle.label(9))
                }.help("\(provider == "claude" ? "Claude" : "Codex"): \(shown) shown, \(captured) captured, including parked conversations. \(store.health[provider] ?? "Connecting")")
                    .accessibilityElement(children: .ignore).accessibilityLabel("\(provider == "claude" ? "Claude" : "Codex"): \(shown) shown, \(captured) captured")
            }
            Text("\(store.visible.count) OF \(store.parking ? store.parkedCount : store.cards.count - store.parkedCount) \(store.parking ? "PARKED" : "SHOWN")").font(BoardStyle.label(8)).tracking(0.7).padding(.leading, 3)
            if store.selectedProject != nil || !store.search.isEmpty {
                Button("Clear filters") { store.selectProject(nil) }.buttonStyle(.plain).font(appearance.font(10, weight: .semibold)).foregroundStyle(appearance.ink)
            }
            Spacer()
            if store.summaryIssue != nil || !store.saved.aiEnabled {
                Button { settings = true } label: {
                    Label(store.summaryIssue == nil ? "Summaries off" : "Summaries paused", systemImage: "text.bubble")
                }.buttonStyle(.plain).font(appearance.font(9)).foregroundStyle(appearance.ink).help("Open summary settings")
            } else if store.isSummarizing {
                Text("Summarizing…").font(appearance.font(9))
            }
            if store.statusCheckMessage == nil && !store.scanning {
                Text("LOCAL PREVIEW").font(BoardStyle.label(8)).tracking(0.9).foregroundStyle(appearance.muted.opacity(0.65))
            }
            Rectangle().fill(appearance.line).frame(width: 1, height: 10).padding(.horizontal, 3)
            Text(store.scanning ? "Reading source history…" : store.statusCheckMessage ?? store.updatedAt.map { "Synced " + $0.formatted(date: .omitted, time: .shortened) } ?? "Connecting…")
                .font(appearance.font(9)).lineLimit(1)
            StatusRetryButton(store: store)
        }.foregroundStyle(appearance.muted).padding(.horizontal, 19).padding(.vertical, 9)
    }
}

struct StatusRetryButton: View {
    @Environment(\.boardAppearance) private var appearance
    @ObservedObject var store: BoardStore
    var body: some View {
        Button { store.retryStatus() } label: {
            Label(store.scanning ? "Checking…" : "Retry status", systemImage: "arrow.clockwise")
                .font(appearance.font(10, weight: .semibold)).fixedSize()
                .padding(.horizontal, 7).padding(.vertical, 4)
                .background(appearance.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain).disabled(store.scanning).accessibilityLabel("Retry status")
            .accessibilityValue(store.scanning ? "Checking" : store.statusCheckMessage ?? "Ready")
            .help("Reread Claude and Codex history for every tracked conversation, including parked cards. " + (store.statusCheckMessage ?? ""))
    }
}

struct ConversationCard: View, Equatable {
    @Environment(\.boardAppearance) private var appearance
    let store: BoardStore
    let card: Conversation
    let project: Project?
    let projects: [Project]
    let disposition: Disposition
    let displayedColumn: Column
    let latestSummary: String?
    var compact = false
    var opensProjectBoard = false
    var showProject: ((String) -> Void)? = nil
    let showHistory: () -> Void
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.store === rhs.store && lhs.card == rhs.card && lhs.project == rhs.project && lhs.projects == rhs.projects && lhs.disposition == rhs.disposition && lhs.displayedColumn == rhs.displayedColumn && lhs.latestSummary == rhs.latestSummary && lhs.compact == rhs.compact && lhs.opensProjectBoard == rhs.opensProjectBoard
    }
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
            }.padding(.horizontal, compact ? 8 : 10).padding(.vertical, compact ? 6 : 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(appearance.theme == .brutalist ? Color.black : Color.clear)
                .padding(.bottom, appearance.theme == .brutalist ? 8 : 0)
            if !compact || !collapsed {
                VStack(alignment: .leading, spacing: 0) {
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
                    }.buttonStyle(.plain).padding(.top, compact ? 5 : collapsed ? 4 : 10).help("Open \(card.title) in \(card.providerName)")
                        .onDrag { NSItemProvider(object: card.id as NSString) } preview: {
                            Text(card.title).font(appearance.font(12, weight: .semibold)).lineLimit(1).padding(10).frame(width: 200).background(color.wash, in: RoundedRectangle(cornerRadius: 8))
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
                        }.foregroundStyle(appearance.muted)
                        if disposition.parked {
                            Button { store.park(card, false) } label: { Label("Restore to board", systemImage: "arrow.uturn.backward").font(appearance.font(10, weight: .medium)) }.buttonStyle(.plain).foregroundStyle(appearance.ink).padding(.top, 9)
                        }
                    }
                }.padding(.horizontal, compact ? 8 : 10).padding(.bottom, compact ? 2 : collapsed ? 8 : 11)
            }
            if compact && collapsed {
                HStack { providerButton; Spacer(minLength: 0) }
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
                HStack { Text("\(card.requests.count) requests · newest first").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Summarize history") { store.summarizeHistory(card) }.disabled(!store.saved.aiEnabled) }
            }
        }.font(appearance.font(12)).padding(20).frame(width: 520, height: 470).background(appearance.canvas).foregroundStyle(appearance.ink)
    }
}

struct SettingsView: View {
    @Environment(\.boardAppearance) private var appearance
    @ObservedObject var store: BoardStore
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var model = ""
    @State private var restoreURL: URL?
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
struct ProjectsView: View {
    @Environment(\.boardAppearance) private var appearance
    @ObservedObject var store: BoardStore
    @State private var newName = ""
    @State private var iconProjectID: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Group {
            if let id = iconProjectID, let project = store.saved.projects.first(where: { $0.id == id }) {
                ProjectIconLibrary(store: store, project: project) { iconProjectID = nil }
            } else {
                projectList
            }
        }.font(appearance.font(12)).textFieldStyle(.roundedBorder).padding(24).frame(width: 500, height: 450).background(appearance.canvas).foregroundStyle(appearance.ink)
    }
    private var projectList: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("Projects").font(.title2.bold()); Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }
            Text("Give each project a familiar icon and color. Moving a card locks its project until you change it.").font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(store.saved.projects) { p in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Button { iconProjectID = p.id } label: {
                                    Image(systemName: store.projectSymbol(p).systemName).font(.system(size: 17, weight: .semibold))
                                        .frame(width: 32, height: 32).background(appearance.paper, in: RoundedRectangle(cornerRadius: 7))
                                }.buttonStyle(.plain).foregroundStyle(appearance.project(store.projectColor(p)).accent)
                                    .help("Change icon for \(p.name)").accessibilityLabel("Change icon for \(p.name)")
                                TextField("Project name", text: Binding(get: { store.saved.projects.first(where: { $0.id == p.id })?.name ?? "" }, set: { store.renameProject(p.id, $0) })).font(appearance.font(12.5, weight: .semibold))
                            }
                            TextField("Near-term goal", text: Binding(get: { store.saved.projects.first(where: { $0.id == p.id })?.note ?? "" }, set: { store.setNote(p.id, $0) }), axis: .vertical).font(.caption)
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 8), count: 12), alignment: .leading, spacing: 5) {
                                ForEach(Array(ProjectColor.palette.enumerated()), id: \.offset) { index, color in
                                    Button { store.setProjectColor(p.id, index) } label: {
                                        Circle().fill(color.accent).frame(width: 19, height: 19)
                                            .overlay { if p.colorIndex == index { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white) } }
                                            .frame(width: 24, height: 24).contentShape(Rectangle())
                                    }.buttonStyle(.plain).help(color.name).accessibilityLabel("\(color.name) color for \(p.name)")
                                        .accessibilityValue(p.colorIndex == index ? "Selected" : "")
                                }
                            }.padding(.top, 3)
                        }
                        .padding(11).background(appearance.project(store.projectColor(p)).wash, in: RoundedRectangle(cornerRadius: 9))
                    }
                }
            }
            HStack { TextField("New project", text: $newName); Button("Add") { store.addProject(newName); newName = "" }.disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty) }
        }
    }
}

struct ProjectIconLibrary: View {
    @Environment(\.boardAppearance) private var appearance
    @ObservedObject var store: BoardStore
    let project: Project
    let done: () -> Void
    @State private var query = ""
    @State private var category: String?
    @FocusState private var searchFocused: Bool
    var body: some View {
        let color = appearance.project(store.projectColor(project))
        let matches = ProjectSymbol.matchingIndices(query: query, category: category)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Choose an icon").font(appearance.font(18, weight: .semibold))
                    Label(project.name, systemImage: store.projectSymbol(project).systemName).font(appearance.font(12, weight: .semibold)).foregroundStyle(color.accent).lineLimit(1)
                }
                Spacer()
                Button("Back", action: done).keyboardShortcut(.cancelAction)
            }
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(appearance.muted)
                TextField("Search icons — boats, math, writing…", text: $query).textFieldStyle(.plain).focused($searchFocused).accessibilityLabel("Search project icons")
                if !query.isEmpty {
                    Button { query = ""; searchFocused = true } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).help("Clear icon search").accessibilityLabel("Clear icon search")
                }
            }.padding(10).background(appearance.paper, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(appearance.line, lineWidth: 1))
            HStack {
                Picker("Category", selection: $category) {
                    Text("All icons").tag(String?.none)
                    ForEach(ProjectSymbol.categories, id: \.self) { Text($0).tag(Optional($0)) }
                }.labelsHidden().frame(width: 170).accessibilityLabel("Icon category")
                Spacer()
                Text("\(matches.count) icons").font(BoardStyle.label(10)).foregroundStyle(appearance.muted)
            }
            if matches.isEmpty {
                VStack(spacing: 8) {
                    Text("No matching icons").font(appearance.font(13, weight: .semibold))
                    Button("Show all icons") { query = ""; category = nil; searchFocused = true }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 9), spacing: 7) {
                        ForEach(matches, id: \.self) { index in
                            let symbol = ProjectSymbol.palette[index]
                            Button { store.setProjectSymbol(project.id, index); done() } label: {
                                Image(systemName: symbol.systemName).font(.system(size: 20, weight: .medium)).frame(maxWidth: .infinity).frame(height: 39)
                                    .background(project.symbolIndex == index ? color.wash : appearance.paper, in: RoundedRectangle(cornerRadius: 7))
                                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(project.symbolIndex == index ? color.accent : appearance.line, lineWidth: project.symbolIndex == index ? 1.5 : 0.7))
                            }.buttonStyle(.plain).foregroundStyle(color.accent).help(symbol.name)
                                .accessibilityLabel("\(symbol.name) icon for \(project.name)").accessibilityValue(project.symbolIndex == index ? "Selected" : "")
                        }
                    }.padding(2)
                }.id([category ?? "", query])
            }
        }.onAppear { searchFocused = true }
    }
}
