import KanbananaCore
import KanbananaServices
import AppKit
import XCTest
@testable import AgentKanban

final class PhotoLibraryTests: XCTestCase {
    func testSelectingAnyPhotoMatchesBackdropThenContinuesHourlyRotation() {
        let now = Date(timeIntervalSince1970: 3600 * 1234 + 15)
        for context in ["Math interactives", "Cannes boats", "Writing", ""] {
            for selected in PhotoBackdrop.photos.indices {
                let offset = PhotoBackdrop.offset(selecting: selected, at: now, context: context)
                XCTAssertEqual(PhotoBackdrop.index(at: now, offset: offset, context: context), selected)
                XCTAssertEqual(PhotoBackdrop.index(at: now.addingTimeInterval(3600), offset: offset, context: context), (selected + 1) % PhotoBackdrop.photos.count)
            }
        }
        XCTAssertTrue(PhotoBackdrop.photos.indices.contains(PhotoBackdrop.index(at: now, offset: -100, context: "")))
    }

    @MainActor func testAllLibraryAssetsDecodeAtBoundedSizesAndHaveCredits() async throws {
        let resourceRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
        XCTAssertEqual(Set(PhotoBackdrop.assetNames).count, PhotoBackdrop.photos.count)
        for photo in PhotoBackdrop.photos {
            XCTAssertFalse(photo.credit.isEmpty)
            XCTAssertFalse(photo.license.isEmpty)
            let thumbnail = try XCTUnwrap(PhotoImageLoader.shared.image(for: photo, thumbnail: true, resourceRoot: resourceRoot), photo.filename)
            XCTAssertLessThanOrEqual(max(thumbnail.size.width, thumbnail.size.height), 400)
            let full = try XCTUnwrap(PhotoImageLoader.shared.image(for: photo, resourceRoot: resourceRoot), photo.filename)
            XCTAssertLessThanOrEqual(max(full.size.width, full.size.height), 2048)
            let bitmap = try XCTUnwrap(full.cgImage(forProposedRect: nil, context: nil, hints: nil))
            XCTAssertEqual(bitmap.colorSpace?.model, .monochrome)
            if photo.filename.hasSuffix(".jpg") {
                XCTAssertEqual(photo.source?.host, "commons.wikimedia.org")
                XCTAssertFalse(photo.recognition.isEmpty)
            }
        }
    }

    func testFocalCropsCoverNarrowAndWideWindowsWithoutGaps() {
        for image in [CGSize(width: 1024, height: 1536), CGSize(width: 5045, height: 3342)] {
            for viewport in [CGSize(width: 280, height: 1100), CGSize(width: 300, height: 740), CGSize(width: 1200, height: 600)] {
                for focal in [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.8, y: 0.1), CGPoint(x: 0, y: 1)] {
                    let frame = PhotoBackdrop.cropFrame(image: image, viewport: viewport, focalPoint: focal)
                    XCTAssertLessThanOrEqual(frame.minX, 0)
                    XCTAssertLessThanOrEqual(frame.minY, 0)
                    XCTAssertGreaterThanOrEqual(frame.maxX + 0.001, viewport.width)
                    XCTAssertGreaterThanOrEqual(frame.maxY + 0.001, viewport.height)
                    XCTAssertEqual(frame.width / frame.height, image.width / image.height, accuracy: 0.001)
                    let subject = CGPoint(x: frame.minX + frame.width * focal.x, y: frame.minY + frame.height * focal.y)
                    XCTAssertTrue(CGRect(origin: .zero, size: viewport).insetBy(dx: -0.001, dy: -0.001).contains(subject))
                }
            }
        }
    }
}
