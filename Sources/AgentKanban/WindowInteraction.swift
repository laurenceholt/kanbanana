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

/// Catch an activation click in the content view, not in NSWindow.sendEvent.
/// AppKit must see every event in a window move/resize sequence, even when the
/// board underneath should not respond to the click that brought it forward.
final class ActivationClickShield: NSView {
    var isArmed = false
    override func hitTest(_ point: NSPoint) -> NSView? {
        isArmed && bounds.contains(convert(point, from: superview)) ? self : nil
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    override func mouseDragged(with event: NSEvent) { }
    override func mouseUp(with event: NSEvent) { isArmed = false }
}

final class BoardWindow: NSWindow {
    private let activationShield = ActivationClickShield()

    convenience init(contentSize: NSSize) {
        // Reserve a real AppKit titlebar. Extending the hosting view underneath
        // it makes window gestures compete with SwiftUI content hit testing.
        self.init(contentRect: NSRect(origin: .zero, size: contentSize),
                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                  backing: .buffered, defer: false)
        isMovable = true
        isMovableByWindowBackground = false
        titlebarAppearsTransparent = false
        isReleasedWhenClosed = false
    }

    /// Called once after the hosting view is installed. The shield is normally
    /// transparent to hit testing; card controls and card drags remain unchanged.
    func installActivationShield() {
        guard let contentView else { return }
        // Keep the shield outside SwiftUI's managed subview hierarchy so view
        // updates cannot remove or reorder it. Native sizing owns the wrapper.
        let container = NSView(frame: contentView.frame)
        self.contentView = container
        contentView.frame = container.bounds
        contentView.autoresizingMask = [.width, .height]
        container.addSubview(contentView)
        activationShield.frame = container.bounds
        activationShield.autoresizingMask = [.width, .height]
        container.addSubview(activationShield)
    }

    static func isContentClick(_ point: NSPoint, layoutRect: NSRect) -> Bool {
        // Use AppKit's actual content layout, not a guessed title-bar height.
        // Leave a generous native resize zone at every edge.
        layoutRect.insetBy(dx: 12, dy: 12).contains(point)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            activationShield.isArmed = !isKeyWindow && attachedSheet == nil
                && Self.isContentClick(event.locationInWindow, layoutRect: contentLayoutRect)
                && WindowCoverage.isCovered(self)
        }
        // Never drop an event here: doing so can interrupt native window tracking.
        super.sendEvent(event)
        if event.type == .leftMouseUp { activationShield.isArmed = false }
    }
    override func resignKey() {
        activationShield.isArmed = false
        super.resignKey()
    }
    override func cancelOperation(_ sender: Any?) {
        activationShield.isArmed = false
        if CardDragSession.activeID != nil { CardDragSession.cancel() }
        else { performClose(sender) }
    }
}
