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
}
