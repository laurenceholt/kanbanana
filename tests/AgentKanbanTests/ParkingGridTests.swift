import KanbananaCore
import KanbananaServices
import XCTest
@testable import AgentKanban

final class ParkingGridTests: XCTestCase {
    func testRowsUseMeasuredHeightAndKeepEveryCardInsideTheViewport() {
        let heights: [CGFloat] = [120, 240, 160, 80, 200, 130, 310]
        for width: CGFloat in [1, 260, 728, 808, 1010, 1500] {
            let layout = ParkingGridGeometry(width: width, count: heights.count) { index, _ in heights[index] }
            XCTAssertEqual(layout.frames.count, heights.count)
            for (index, frame) in layout.frames.enumerated() {
                XCTAssertEqual(frame.height, heights[index])
                XCTAssertGreaterThanOrEqual(frame.minX, 0)
                XCTAssertLessThanOrEqual(frame.maxX, width + 0.01)
                XCTAssertLessThanOrEqual(frame.width, 230)
                XCTAssertLessThanOrEqual(frame.maxY, layout.size.height)
                for other in layout.frames.dropFirst(index + 1) { XCTAssertFalse(frame.intersects(other)) }
            }
        }
    }

    func testContentChangesReflowRowsWithoutRetainingEarlierHeightEstimates() {
        let small = ParkingGridGeometry(width: 600, count: 7) { _, _ in 100 }
        let changed = ParkingGridGeometry(width: 600, count: 7) { index, _ in index == 1 ? 300 : 100 }
        XCTAssertEqual(small.frames[3].minY, 110)
        XCTAssertEqual(changed.frames[3].minY, 310)
        XCTAssertEqual(changed.frames[6].minY, 420)
        XCTAssertEqual(ParkingGridGeometry(width: 600, count: 7) { _, _ in 100 }.frames, small.frames)
        XCTAssertEqual(ParkingGridGeometry(width: 600, count: 0) { _, _ in XCTFail("Empty grid must not measure cards"); return 0 }.size.height, 0)
    }

    func testMeasurementsUseTheSameWidthAsPlacementAcrossColumnBreakpoints() {
        for width: CGFloat in [379, 380, 574, 575, 769, 770] {
            var measuredWidths: [CGFloat] = []
            let layout = ParkingGridGeometry(width: width, count: 40) { _, cardWidth in
                measuredWidths.append(cardWidth)
                return cardWidth < 200 ? 200 : 150
            }
            XCTAssertEqual(measuredWidths, layout.frames.map(\.width))
            XCTAssertEqual(Set(layout.frames.map(\.width)).count, 1)
        }
        for width: CGFloat? in [nil, .infinity, .nan] {
            XCTAssertEqual(ParkingGridGeometry(width: width, count: 1) { _, _ in 120 }.size, CGSize(width: 230, height: 120))
        }
    }
}
