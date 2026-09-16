import KanbananaCore
import AppKit
import SwiftUI

enum BoardStyle {
    static let ink = Color(hex: 0x24333B)
    static let muted = Color(hex: 0x5D6661)
    static let canvas = BoardBackground.brightYellow.color
    static let line = Color(hex: 0xDCDDD4)
    static let paper = CardPaper.cream.color
    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let face = weight == .bold ? "AvenirNext-Bold" : weight == .semibold ? "AvenirNext-DemiBold" : weight == .medium ? "AvenirNext-Medium" : "AvenirNext-Regular"
        return .custom(face, size: size)
    }
    static func label(_ size: CGFloat = 9) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
}

enum BoardBackground: String, CaseIterable {
    case emergencyYellow, hiVisYellow, signalYellow, brightYellow, butter, softYellow, sage, powderBlue, warmGray
    static let preferenceKey = "boardBackground"
    var title: String {
        switch self {
        case .emergencyYellow: "Emergency yellow"
        case .hiVisYellow: "Hi-vis yellow"
        case .signalYellow: "Signal yellow"
        case .brightYellow: "Bright yellow"
        case .butter: "Butter"
        case .softYellow: "Soft yellow"
        case .sage: "Sage"
        case .powderBlue: "Powder blue"
        case .warmGray: "Warm gray"
        }
    }
    var color: Color {
        switch self {
        case .emergencyYellow: Color(hex: 0xFFFF00)
        case .hiVisYellow: Color(hex: 0xE6FF00)
        case .signalYellow: Color(hex: 0xFFD600)
        case .brightYellow: Color(hex: 0xFFE14D)
        case .butter: Color(hex: 0xF7E7A1)
        case .softYellow: Color(hex: 0xF9F4DD)
        case .sage: Color(hex: 0xE2E9DB)
        case .powderBlue: Color(hex: 0xDDE8F0)
        case .warmGray: Color(hex: 0xE8E5DE)
        }
    }
}

enum CardPaper: String, CaseIterable {
    case cream, oat, mist, white
    static let preferenceKey = "cardPaper"
    var title: String {
        switch self { case .cream: "Cream"; case .oat: "Oat"; case .mist: "Mist"; case .white: "White" }
    }
    var color: Color {
        switch self {
        case .cream: Color(hex: 0xF7EED6)
        case .oat: Color(hex: 0xEEE6D7)
        case .mist: Color(hex: 0xEDF0ED)
        case .white: Color(hex: 0xFFFEFA)
        }
    }
}

enum BoardTheme: String, CaseIterable {
    case classic, night, brutalist, photos
    static let preferenceKey = "boardTheme"
    var title: String { switch self { case .classic: "Classic"; case .night: "Night"; case .brutalist: "Brutalist"; case .photos: "Photos" } }
    var symbol: String { switch self { case .classic: "paintpalette"; case .night: "moon.stars"; case .brutalist: "textformat.abc"; case .photos: "photo" } }
}

struct BoardAppearance: Equatable {
    var background: BoardBackground = .brightYellow
    var cards: CardPaper = .cream
    var theme: BoardTheme = .classic
    var isDark: Bool { theme == .night || theme == .photos }
    var scheme: ColorScheme { isDark ? .dark : .light }
    var canvas: Color { isDark ? .black : theme == .brutalist ? Color(hex: 0xDEDCD4) : background.color }
    var paper: Color { isDark ? Color(hex: 0x191B1E).opacity(theme == .photos ? 0.88 : 1) : theme == .brutalist ? Color(hex: 0xF2F0E7) : cards.color }
    var ink: Color { isDark ? Color(hex: 0xF5F5F2) : theme == .brutalist ? .black : BoardStyle.ink }
    var muted: Color { isDark ? Color(hex: 0xB9BDBF) : BoardStyle.muted }
    var line: Color { isDark ? Color.white.opacity(0.18) : theme == .brutalist ? .black : BoardStyle.line }
    var shadow: Color { .black.opacity(theme == .photos ? 0.4 : theme == .brutalist ? 1 : 0.07) }
    var cornerRadius: CGFloat { theme == .brutalist ? 0 : 10 }
    var borderWidth: CGFloat { theme == .brutalist ? 2 : 0.8 }
    func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        theme == .brutalist ? .system(size: size, weight: weight, design: .monospaced) : BoardStyle.font(size, weight: weight)
    }
    func accent(_ color: Color) -> Color {
        guard isDark, let rgb = NSColor(color).usingColorSpace(.sRGB) else { return color }
        // Preserve project hue, with enough lightness for names on charcoal.
        return Color(.sRGB, red: 0.45 + rgb.redComponent * 0.55, green: 0.45 + rgb.greenComponent * 0.55, blue: 0.45 + rgb.blueComponent * 0.55)
    }
    func stripe(_ color: Color) -> Color {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return color }
        // Stripes can carry a stronger hue than text without sacrificing label contrast.
        return Color(nsColor: NSColor(hue: rgb.hueComponent,
                                     saturation: min(1, rgb.saturationComponent * 1.18),
                                     brightness: isDark ? max(0.82, rgb.brightnessComponent) : min(0.92, rgb.brightnessComponent * 1.08),
                                     alpha: 1))
    }
    func project(_ color: ProjectColor) -> ProjectColor {
        isDark ? .init(name: color.name, accent: accent(color.accent), wash: color.accent.opacity(0.22), edge: accent(color.edge).opacity(0.4)) : color
    }
    static func saved(in preferences: UserDefaults = .standard) -> Self {
        Self(background: preferences.string(forKey: BoardBackground.preferenceKey).flatMap(BoardBackground.init(rawValue:)) ?? .brightYellow,
             cards: preferences.string(forKey: CardPaper.preferenceKey).flatMap(CardPaper.init(rawValue:)) ?? .cream,
             theme: preferences.string(forKey: BoardTheme.preferenceKey).flatMap(BoardTheme.init(rawValue:)) ?? .classic)
    }
}

private struct BoardAppearanceKey: EnvironmentKey {
    static let defaultValue = BoardAppearance()
}
extension EnvironmentValues {
    var boardAppearance: BoardAppearance {
        get { self[BoardAppearanceKey.self] }
        set { self[BoardAppearanceKey.self] = newValue }
    }
}

struct AppearanceMenu: View {
    @Environment(\.boardAppearance) private var appearance
    @Binding var background: BoardBackground
    @Binding var cards: CardPaper
    @Binding var theme: BoardTheme
    @Binding var photoOffset: Int
    var photoContext: String = ""
    @State private var photoLibrary = false
    var body: some View {
        Menu {
            Picker("Appearance", selection: $theme) {
                ForEach(BoardTheme.allCases, id: \.self) { option in Label(option.title, systemImage: option.symbol).tag(option) }
            }.pickerStyle(.inline)
            if theme == .photos {
                Button("Photo library…") { photoLibrary = true }
                Button("Next photo") { photoOffset = (photoOffset + 1) % PhotoBackdrop.assetNames.count }
                Text("Changes every hour · stored on this Mac")
            }
            Divider()
            Menu("Classic colors") {
                Picker("Background", selection: $background) {
                    ForEach(BoardBackground.allCases, id: \.self) { option in
                        Label { Text(option.title) } icon: { Image(nsImage: swatch(option.color)) }.tag(option)
                    }
                }.pickerStyle(.inline)
                Divider()
                Picker("Cards & project headers", selection: $cards) {
                    ForEach(CardPaper.allCases, id: \.self) { option in
                        Label { Text(option.title) } icon: { Image(nsImage: swatch(option.color)) }.tag(option)
                    }
                }.pickerStyle(.inline)
            }
            Divider()
            Button("Restore previous look") { theme = .classic; background = .softYellow; cards = .white }
        } label: {
            Image(systemName: "paintpalette").font(.system(size: 13)).frame(width: 28, height: 28)
                .foregroundStyle(appearance.ink)
                .background(appearance.ink.opacity(0.065), in: RoundedRectangle(cornerRadius: appearance.theme == .brutalist ? 0 : 8))
        }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help("Appearance — background and card colors").accessibilityLabel("Appearance")
            .sheet(isPresented: $photoLibrary) { PhotoLibraryView(photoOffset: $photoOffset, context: photoContext) }
    }
    private func swatch(_ color: Color) -> NSImage {
        NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            let shape = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
            NSColor(color).setFill(); shape.fill()
            NSColor.black.withAlphaComponent(0.18).setStroke(); shape.lineWidth = 0.7; shape.stroke()
            return true
        }
    }
}

extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1) }
}
struct ProjectColor {
    let name: String
    let accent: Color
    let wash: Color
    let edge: Color
    static let palette: [ProjectColor] = [
        .init(name: "Fern", accent: Color(hex: 0x226D42), wash: Color(hex: 0xDCEFE3), edge: Color(hex: 0xB5D5C0)),
        .init(name: "Clay", accent: Color(hex: 0xAA4319), wash: Color(hex: 0xFBE5D5), edge: Color(hex: 0xE9B99E)),
        .init(name: "Iris", accent: Color(hex: 0x6742B1), wash: Color(hex: 0xECE3FC), edge: Color(hex: 0xCFBDEC)),
        .init(name: "Harbor", accent: Color(hex: 0x225CAF), wash: Color(hex: 0xDFECFF), edge: Color(hex: 0xAEC9EC)),
        .init(name: "Ochre", accent: Color(hex: 0x896200), wash: Color(hex: 0xFFF1C5), edge: Color(hex: 0xE0CA81)),
        .init(name: "Rose", accent: Color(hex: 0xAD315B), wash: Color(hex: 0xFBE1EB), edge: Color(hex: 0xE6ABC0)),
        .init(name: "Lagoon", accent: Color(hex: 0x006F75), wash: Color(hex: 0xD6F1EF), edge: Color(hex: 0x99CFCB)),
        .init(name: "Slate", accent: Color(hex: 0x475266), wash: Color(hex: 0xE4E8EF), edge: Color(hex: 0xBCC5D5)),
        .init(name: "Scarlet", accent: Color(hex: 0xAE332A), wash: Color(hex: 0xFBDDD8), edge: Color(hex: 0xE7AAA4)),
        .init(name: "Crimson", accent: Color(hex: 0x88213D), wash: Color(hex: 0xF2D8DF), edge: Color(hex: 0xD5A0AF)),
        .init(name: "Peach", accent: Color(hex: 0x9B5338), wash: Color(hex: 0xFFE9DF), edge: Color(hex: 0xECC4B2)),
        .init(name: "Amber", accent: Color(hex: 0x945600), wash: Color(hex: 0xFFE6B6), edge: Color(hex: 0xE8C386)),
        .init(name: "Lime", accent: Color(hex: 0x556D18), wash: Color(hex: 0xEAF2CD), edge: Color(hex: 0xC8D793)),
        .init(name: "Sage", accent: Color(hex: 0x55684D), wash: Color(hex: 0xE8ECDD), edge: Color(hex: 0xC3CEB4)),
        .init(name: "Mint", accent: Color(hex: 0x1E7157), wash: Color(hex: 0xD3F4DD), edge: Color(hex: 0xA2DABB)),
        .init(name: "Seafoam", accent: Color(hex: 0x42746D), wash: Color(hex: 0xE1F4E8), edge: Color(hex: 0xB9DACC)),
        .init(name: "Aqua", accent: Color(hex: 0x08728C), wash: Color(hex: 0xD5F2FA), edge: Color(hex: 0xA3D7E6)),
        .init(name: "Sky", accent: Color(hex: 0x3375A0), wash: Color(hex: 0xE7F4FF), edge: Color(hex: 0xBEDAF0)),
        .init(name: "Navy", accent: Color(hex: 0x293E78), wash: Color(hex: 0xDDE3F6), edge: Color(hex: 0xADBBDC)),
        .init(name: "Periwinkle", accent: Color(hex: 0x595DA0), wash: Color(hex: 0xEEEEFF), edge: Color(hex: 0xCACCEE)),
        .init(name: "Plum", accent: Color(hex: 0x71355F), wash: Color(hex: 0xEDDCEB), edge: Color(hex: 0xD3B1CB)),
        .init(name: "Orchid", accent: Color(hex: 0x91409D), wash: Color(hex: 0xF6DFF9), edge: Color(hex: 0xE0B2E7)),
        .init(name: "Cocoa", accent: Color(hex: 0x70503A), wash: Color(hex: 0xEEE1D2), edge: Color(hex: 0xD4BDA7)),
        .init(name: "Graphite", accent: Color(hex: 0x404447), wash: Color(hex: 0xE2E3E1), edge: Color(hex: 0xBFC2BD))
    ]
    static let ungrouped = ProjectColor(name: "Ungrouped", accent: BoardStyle.muted, wash: Color(hex: 0xEFEEE9), edge: BoardStyle.line)
    static func nextIndex(in projects: [Project]) -> Int {
        let used = Set(projects.compactMap(\.colorIndex))
        return palette.indices.first { !used.contains($0) } ?? projects.count % palette.count
    }
}
extension BoardStore {
    func projectColor(_ project: Project?) -> ProjectColor {
        guard let project else { return .ungrouped }
        let index = project.colorIndex ?? saved.projects.firstIndex(where: { $0.id == project.id }) ?? 0
        return ProjectColor.palette[abs(index % ProjectColor.palette.count)]
    }

    func projectSymbol(_ project: Project?) -> ProjectSymbol {
        guard let project else { return .init(name: "Ungrouped", systemName: "square.dashed") }
        let index = project.symbolIndex ?? saved.projects.firstIndex(where: { $0.id == project.id }) ?? 0
        return ProjectSymbol.palette[abs(index % ProjectSymbol.palette.count)]
    }

}

// Use the actual installed app icons, without copying vendor artwork into our bundle.
enum ProviderArtwork {
    static let claude = load("com.anthropic.claudefordesktop")
    static let codex = load("com.openai.codex")
    private static func load(_ bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
struct ProviderIcon: View {
    let provider: String
    var size: CGFloat = 19
    var body: some View {
        Group {
            if let image = provider == "claude" ? ProviderArtwork.claude : ProviderArtwork.codex {
                Image(nsImage: image).resizable().interpolation(.high)
            } else {
                Image(systemName: provider == "claude" ? "asterisk" : "circle.hexagongrid.fill").resizable().scaledToFit().padding(3)
            }
        }
        .frame(width: size, height: size)
        .help(provider == "claude" ? "Claude" : "Codex")
        .accessibilityLabel(provider == "claude" ? "Claude" : "Codex")
    }
}

struct QuietIconButton: ButtonStyle {
    @Environment(\.boardAppearance) private var appearance
    var dark = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(width: 28, height: 28)
            .background((dark ? Color.white : appearance.ink).opacity(configuration.isPressed ? 0.15 : 0.065), in: RoundedRectangle(cornerRadius: appearance.theme == .brutalist ? 0 : 8))
            .foregroundStyle(dark ? Color(hex: 0xE4E9E2) : appearance.ink)
    }
}

func activityLabel(_ timestamp: Double, now: Date = Date()) -> String {
    let seconds = max(0, Int(now.timeIntervalSince1970 - timestamp))
    if seconds < 60 { return "just now" }
    if seconds < 3600 { return "\(seconds / 60)m ago" }
    if seconds < 86400 { return "\(seconds / 3600)h ago" }
    return "\(seconds / 86400)d ago"
}
