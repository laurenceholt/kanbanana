import KanbananaCore
import KanbananaServices
import AppKit
import XCTest
@testable import AgentKanban

final class ArtLibraryTests: XCTestCase {
    func testSelectingAnyArtworkMatchesBackdropThenContinuesHourlyRotation() {
        let now = Date(timeIntervalSince1970: 3600 * 1234 + 15)
        for context in ["Math interactives", "Cannes boats", "Writing", ""] {
            for selected in ArtBackdrop.artworks.indices {
                let offset = ArtBackdrop.offset(selecting: selected, at: now, context: context)
                XCTAssertEqual(ArtBackdrop.index(at: now, offset: offset, context: context), selected)
                XCTAssertEqual(ArtBackdrop.index(at: now.addingTimeInterval(3600), offset: offset, context: context), (selected + 1) % ArtBackdrop.artworks.count)
            }
        }
        XCTAssertTrue(ArtBackdrop.artworks.indices.contains(ArtBackdrop.index(at: now, offset: -100, context: "")))
    }

    @MainActor func testAllLibraryAssetsDecodeAtBoundedSizesAndHaveCredits() async throws {
        let resourceRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources")
        XCTAssertEqual(Set(ArtBackdrop.assetNames).count, ArtBackdrop.artworks.count)
        for artwork in ArtBackdrop.artworks {
            XCTAssertFalse(artwork.credit.isEmpty)
            XCTAssertFalse(artwork.license.isEmpty)
            let thumbnail = try XCTUnwrap(ArtImageLoader.shared.image(for: artwork, thumbnail: true, resourceRoot: resourceRoot), artwork.filename)
            XCTAssertLessThanOrEqual(max(thumbnail.size.width, thumbnail.size.height), ceil(400 * artwork.zoom))
            let full = try XCTUnwrap(ArtImageLoader.shared.image(for: artwork, resourceRoot: resourceRoot), artwork.filename)
            XCTAssertLessThanOrEqual(max(full.size.width, full.size.height), 2048)
            let bitmap = try XCTUnwrap(full.cgImage(forProposedRect: nil, context: nil, hints: nil))
            XCTAssertNotNil(bitmap.colorSpace)
            XCTAssertEqual(artwork.source.host, "commons.wikimedia.org")
            XCTAssertTrue(["en.wikipedia.org", "www.guggenheim-bilbao.eus"].contains(artwork.article.host ?? ""))
            XCTAssertTrue(artwork.caption.contains(artwork.title))
            XCTAssertTrue(artwork.caption.contains(artwork.credit))
            XCTAssertTrue(artwork.caption.contains(artwork.date))
            if artwork.license.hasPrefix("CC BY") { XCTAssertFalse(artwork.imageCredit.isEmpty) }
            XCTAssertFalse(artwork.medium.isEmpty)
            if artwork.id == "wave" { XCTAssertEqual(bitmap.colorSpace?.model, .rgb) }
        }
    }

    func testFocalCropsCoverNarrowAndWideWindowsWithoutGaps() {
        for image in [CGSize(width: 1024, height: 1536), CGSize(width: 5045, height: 3342)] {
            for viewport in [CGSize(width: 280, height: 1100), CGSize(width: 300, height: 740), CGSize(width: 1200, height: 600)] {
                for zoom: CGFloat in [1, 1.5, 2.8] {
                    for focal in [CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.8, y: 0.1), CGPoint(x: 0, y: 1)] {
                        let frame = ArtBackdrop.cropFrame(image: image, viewport: viewport, focalPoint: focal, zoom: zoom)
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
}
