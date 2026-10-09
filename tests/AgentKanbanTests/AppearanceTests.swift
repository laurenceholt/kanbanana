import KanbananaCore
import KanbananaServices
import AppKit
import XCTest
@testable import AgentKanban

final class AppearanceTests: XCTestCase {
    func testThemesRetainClassicColorsAndPersistIndependently() {
        let name = UUID().uuidString
        let preferences = UserDefaults(suiteName: name)!
        defer { preferences.removePersistentDomain(forName: name) }
        preferences.set(BoardBackground.hiVisYellow.rawValue, forKey: BoardBackground.preferenceKey)
        preferences.set(CardPaper.mist.rawValue, forKey: CardPaper.preferenceKey)
        // Existing photo-mode installations adopt the art library without resetting appearance.
        preferences.set("photos", forKey: BoardTheme.preferenceKey)
        XCTAssertEqual(BoardAppearance.saved(in: preferences).theme, .art)
        for theme in BoardTheme.allCases {
            preferences.set(theme.rawValue, forKey: BoardTheme.preferenceKey)
            let saved = BoardAppearance.saved(in: preferences)
            XCTAssertEqual(saved.theme, theme)
            XCTAssertEqual(saved.background, .hiVisYellow)
            XCTAssertEqual(saved.cards, .mist)
        }
    }
    func testDarkThemesUseLightTextAndDarkCardsForEveryPaperChoice() {
        for theme in [BoardTheme.night, .art] {
            for paper in CardPaper.allCases {
                let appearance = BoardAppearance(cards: paper, theme: theme)
                let ink = NSColor(appearance.ink).usingColorSpace(.sRGB)!
                let card = NSColor(appearance.paper).usingColorSpace(.sRGB)!
                XCTAssertGreaterThan(ink.redComponent, 0.9)
                XCTAssertLessThan(card.redComponent, 0.15)
                XCTAssertGreaterThan(card.alphaComponent, 0.85)
                for color in ProjectColor.palette {
                    let accent = NSColor(appearance.project(color).accent).usingColorSpace(.sRGB)!
                    XCTAssertGreaterThanOrEqual(max(accent.redComponent, accent.greenComponent, accent.blueComponent), 0.5)
                }
            }
        }
    }
    func testArtStaysStableWithinHourRotateAndSupportNext() {
        let start = Date(timeIntervalSince1970: 3600 * 100 + 5)
        for context in ["Math interactives", "Cannes boats", "Writing a book", ""] {
            let index = ArtBackdrop.index(at: start, offset: 0, context: context)
            XCTAssertEqual(index, ArtBackdrop.index(at: start.addingTimeInterval(3500), offset: 0, context: context))
            XCTAssertNotEqual(index, ArtBackdrop.index(at: start.addingTimeInterval(3600), offset: 0, context: context))
            XCTAssertNotEqual(index, ArtBackdrop.index(at: start, offset: 1, context: context))
            XCTAssertEqual(index, ArtBackdrop.index(at: start.addingTimeInterval(Double(ArtBackdrop.artworks.count) * 3600), offset: 0, context: context))
        }
    }
}
