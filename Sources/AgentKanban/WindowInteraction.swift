import KanbananaCore
import AppKit

/// Window rectangles use Core Graphics screen coordinates throughout; this also
/// works on displays to the left of or above the main display. No screen pixels,
/// window titles, Accessibility access or screen-recording permission are used.
enum WindowCoverage {
    struct Entry {
        let id: Int
        let bounds: CGRect
        let layer: Int
        let alpha: Double
    }
    static func isCovered(_ id: Int, frontToBack windows: [Entry]) -> Bool {
        guard let index = windows.firstIndex(where: { $0.id == id }) else { return false }
        let target = windows[index]
        return windows[..<index].contains { other in
            guard other.layer == target.layer, other.alpha > 0.05 else { return false }
            let intersection = target.bounds.insetBy(dx: 2, dy: 2).intersection(other.bounds)
            return !intersection.isNull && intersection.width > 2 && intersection.height > 2
        }
    }
    @MainActor static func isCovered(_ window: NSWindow) -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return false }
        let entries = list.compactMap { item -> Entry? in
            guard let number = item[kCGWindowNumber as String] as? Int,
                  let bounds = item[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds) else { return nil }
            return Entry(id: number, bounds: rect, layer: item[kCGWindowLayer as String] as? Int ?? 0,
                         alpha: item[kCGWindowAlpha as String] as? Double ?? 1)
        }
        return isCovered(window.windowNumber, frontToBack: entries)
    }
}

final class BoardWindow: NSWindow {
    private var consumingRaiseClick = false
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            consumingRaiseClick = false
            // Preserve native titlebar buttons and resize gestures. Only the
            // content activation click is consumed, including its drag/up.
            let content = CGRect(x: 6, y: 6, width: max(0, frame.width - 12), height: max(0, frame.height - 30))
            if !isKeyWindow, attachedSheet == nil, content.contains(event.locationInWindow), WindowCoverage.isCovered(self) {
                consumingRaiseClick = true
                NSApp.activate(ignoringOtherApps: true)
                makeKeyAndOrderFront(nil)
                return
            }
        } else if consumingRaiseClick && (event.type == .leftMouseDragged || event.type == .leftMouseUp) {
            if event.type == .leftMouseUp { consumingRaiseClick = false }
            return
        }
        super.sendEvent(event)
    }
    override func cancelOperation(_ sender: Any?) {
        if CardDragSession.activeID != nil { CardDragSession.cancel() }
        else { performClose(sender) }
    }
}
