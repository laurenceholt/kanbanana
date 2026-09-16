import AppKit
import XCTest
@testable import AgentKanban

final class DraggingTests: XCTestCase {
    @MainActor func testDropUsesTargetBoundsAndIgnoresEmptySpace() {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [], backing: .buffered, defer: false)
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        window.contentView = content
        let left = NativeDropRegion(frame: NSRect(x: 20, y: 20, width: 100, height: 100))
        let right = NativeDropRegion(frame: NSRect(x: 160, y: 20, width: 100, height: 100))
        var drops: [String] = []
        for region in [left, right] {
            region.enabled = true; region.clipsToBounds = false
            content.addSubview(region); CardDragSession.register(region)
        }
        left.action = { _ in drops.append("left"); return true }
        right.action = { _ in drops.append("right"); return true }
        defer {
            CardDragSession.cancel()
            CardDragSession.unregister(left); CardDragSession.unregister(right)
        }
        func drop(_ point: NSPoint) {
            CardDragSession.begin(id: "fixture", title: "Fixture", color: .red, window: window)
            CardDragSession.finish(at: point, in: window)
        }
        drop(NSPoint(x: 180, y: 40))
        drop(NSPoint(x: 40, y: 40))
        drop(NSPoint(x: 340, y: 200))
        right.enabled = false
        drop(NSPoint(x: 180, y: 40))
        XCTAssertEqual(drops, ["right", "left"])
        XCTAssertNil(CardDragSession.activeID)
    }
}
