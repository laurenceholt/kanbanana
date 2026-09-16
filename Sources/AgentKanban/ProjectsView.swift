import KanbananaCore
import SwiftUI
import UniformTypeIdentifiers

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
