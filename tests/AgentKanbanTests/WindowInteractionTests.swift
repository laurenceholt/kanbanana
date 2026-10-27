import KanbananaCore
import KanbananaServices
import AppKit
import XCTest
@testable import AgentKanban

final class WindowInteractionTests: XCTestCase {
    private func window(_ id: Int, x: CGFloat, y: CGFloat = 0, width: CGFloat = 300, layer: Int = 0, alpha: Double = 1) -> WindowCoverage.Entry {
        .init(id: id, bounds: CGRect(x: x, y: y, width: width, height: 700), layer: layer, alpha: alpha)
    }
    func testPartialCoverageConsumesActivationButVisibleInactiveWindowDoesNot() {
        let focus = window(1, x: 900)
        XCTAssertTrue(WindowCoverage.isCovered(1, frontToBack: [window(2, x: 1000), focus]))
        XCTAssertFalse(WindowCoverage.isCovered(1, frontToBack: [window(2, x: 0), focus]))
        XCTAssertFalse(WindowCoverage.isCovered(1, frontToBack: [focus, window(2, x: 1000)]))
    }
    func testIgnoresTransparentOverlaysOtherLevelsAndTouchingEdges() {
        let focus = window(1, x: 0)
        for other in [window(2, x: 0, alpha: 0), window(2, x: 0, layer: 25), window(2, x: 300), window(2, x: 0, y: 700)] {
            XCTAssertFalse(WindowCoverage.isCovered(1, frontToBack: [other, focus]))
        }
        XCTAssertFalse(WindowCoverage.isCovered(999, frontToBack: [focus]))
    }
    func testSecondaryDisplaysUseTheSameCoordinateSpace() {
        let focus = window(1, x: -1000, y: -500)
        XCTAssertTrue(WindowCoverage.isCovered(1, frontToBack: [window(2, x: -950, y: -200), focus]))
        XCTAssertFalse(WindowCoverage.isCovered(1, frontToBack: [window(2, x: 0), focus]))
    }

    @MainActor func testActivationGuardLeavesNativeTitlebarAndResizeEdgesAlone() {
        // A tall titlebar and a nonzero content origin must both be respected.
        let layout = NSRect(x: 0, y: 0, width: 300, height: 680)
        XCTAssertTrue(BoardWindow.isContentClick(NSPoint(x: 100, y: 400), layoutRect: layout))
        for point in [NSPoint(x: 150, y: 700), NSPoint(x: 150, y: 679),
                      NSPoint(x: 5, y: 400), NSPoint(x: 295, y: 400),
                      NSPoint(x: 150, y: 5), NSPoint(x: 0, y: 0)] {
            XCTAssertFalse(BoardWindow.isContentClick(point, layoutRect: layout))
        }
        let insetLayout = NSRect(x: 20, y: 40, width: 280, height: 640)
        XCTAssertFalse(BoardWindow.isContentClick(NSPoint(x: 100, y: 45), layoutRect: insetLayout))
    }

    @MainActor func testShieldConsumesOnlyArmedContentClicksAndReleasesAfterMouseUp() {
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 700))
        let shield = ActivationClickShield(frame: NSRect(x: 20, y: 30, width: 200, height: 400))
        parent.addSubview(shield)
        let point = NSPoint(x: 50, y: 60)
        XCTAssertNil(shield.hitTest(point))
        shield.isArmed = true
        XCTAssertTrue(shield.hitTest(point) === shield)
        XCTAssertNil(shield.hitTest(NSPoint(x: 10, y: 10)))
        let up = NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: [],
                                   timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0,
                                   clickCount: 1, pressure: 0)!
        shield.mouseUp(with: up)
        XCTAssertNil(shield.hitTest(point))
    }

    @MainActor func testNativeChromeStaysOutsideBoardAndContentFollowsResize() {
        let window = BoardWindow(contentSize: NSSize(width: 300, height: 700))
        defer { window.close() }
        XCTAssertTrue(window.isMovable)
        XCTAssertTrue(window.styleMask.contains(.resizable))
        XCTAssertFalse(window.styleMask.contains(.fullSizeContentView))
        XCTAssertLessThan(window.contentLayoutRect.maxY, window.frame.height)
        let board = NSView(frame: window.contentView!.bounds)
        window.contentView = board
        window.installActivationShield()
        for size in [NSSize(width: 360, height: 600), NSSize(width: 280, height: 800)] {
            window.setContentSize(size)
            XCTAssertEqual(board.frame.size, size)
            XCTAssertLessThan(window.contentView!.frame.maxY, window.frame.height)
        }
    }

    @MainActor func testBoardSupportsNativeKeyAndMainWindowActivation() {
        let window = BoardWindow(contentSize: NSSize(width: 300, height: 400))
        defer { window.close() }
        XCTAssertTrue(window.canBecomeKey)
        window.orderBack(nil) // AppKit requires visibility before main-window eligibility.
        XCTAssertTrue(window.canBecomeMain)
        XCTAssertEqual(window.titleVisibility, .visible)
        XCTAssertFalse(window.styleMask.contains(.nonactivatingPanel))
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            XCTAssertTrue(window.standardWindowButton(button)?.isEnabled == true)
        }
    }
}
