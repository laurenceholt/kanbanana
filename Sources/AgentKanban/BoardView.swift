import KanbananaCore
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
        .disabled(store.isLoading)
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
            ForEach(ProviderID.allCases, id: \.self) { source in
                let provider = source.rawValue
                let captured = store.cards.filter { $0.provider == provider }.count
                let shown = store.visible.filter { $0.provider == provider }.count
                HStack(spacing: 4) {
                    ProviderIcon(provider: provider, size: 15)
                    .overlay(alignment: .bottomTrailing) {
                        Circle().fill(store.providerHealth[source]?.status == .connected ? Color(hex: 0x5C8165) : .orange).frame(width: 4, height: 4).overlay(Circle().stroke(appearance.canvas, lineWidth: 1))
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
                Text("LOCAL BETA").font(BoardStyle.label(8)).tracking(0.9).foregroundStyle(appearance.muted.opacity(0.65))
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
