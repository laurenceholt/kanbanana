import KanbananaCore
import AppKit

enum BoardLayout: String, CaseIterable {
    case columns, projects, focus
    var title: String {
        switch self { case .columns: "Columns"; case .projects: "Projects"; case .focus: "Focus" }
    }
    var frameName: String { self == .focus ? "KanbananaFocus" : "AgentKanbanBoard" }
    var minimumSize: NSSize { self == .focus ? NSSize(width: 260, height: 430) : NSSize(width: 760, height: 430) }
    var defaultSize: NSSize { self == .focus ? NSSize(width: 300, height: 740) : NSSize(width: 840, height: 574) }

    func initialFrame(beside previous: NSRect, on screen: NSRect) -> NSRect {
        fitting(NSRect(x: previous.maxX - defaultSize.width, y: previous.maxY - defaultSize.height,
                       width: defaultSize.width, height: defaultSize.height), on: screen)
    }
    func fitting(_ frame: NSRect, on screen: NSRect) -> NSRect {
        let width = min(screen.width, max(minimumSize.width, frame.width))
        let height = min(screen.height, max(minimumSize.height, frame.height))
        return NSRect(x: max(screen.minX, min(frame.minX, screen.maxX - width)),
                      y: max(screen.minY, min(frame.minY, screen.maxY - height)), width: width, height: height)
    }
}
