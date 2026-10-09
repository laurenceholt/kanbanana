import KanbananaCore
import AppKit
import ImageIO
import SwiftUI

struct BackdropArtwork: Identifiable {
    let id: String
    let title: String
    let credit: String
    let medium: String
    let date: String
    let objectID: Int
    var focalPoint = CGPoint(x: 0.5, y: 0.5)
    var zoom: CGFloat = 1
    var filename: String { "\(id).jpg" }
    var license: String { "The Met · Public domain / CC0" }
    var source: URL { URL(string: "https://www.metmuseum.org/art/collection/search/\(objectID)")! }
}

enum ArtBackdrop {
    // Interleave media, palettes and periods; crops are curated for the narrow Focus window.
    // Full museum titles, download provenance and rights evidence live in Resources/Art/catalog.json.
    static let artworks: [BackdropArtwork] = [
        .init(id: "wave", title: "The Great Wave", credit: "Katsushika Hokusai", medium: "Woodblock print", date: "ca. 1830–32", objectID: 39799, focalPoint: .init(x: 0.36, y: 0.43), zoom: 1.65),
        .init(id: "suzani", title: "Suzani flowers", credit: "Bukhara, present-day Uzbekistan; maker unrecorded", medium: "Embroidery", date: "early 19th century", objectID: 447384, focalPoint: .init(x: 0.5, y: 0.43), zoom: 2.15),
        .init(id: "rhinoceros", title: "An imagined rhinoceros", credit: "Albrecht Dürer", medium: "Woodcut", date: "1515", objectID: 356497, focalPoint: .init(x: 0.61, y: 0.53), zoom: 1.8),
        .init(id: "cypresses", title: "Wheat Field with Cypresses", credit: "Vincent van Gogh", medium: "Oil painting", date: "1889", objectID: 436535, focalPoint: .init(x: 0.72, y: 0.38), zoom: 2.1),
        .init(id: "peacock-dish", title: "Peacock in turquoise", credit: "Iznik, Turkey; maker unrecorded", medium: "Ceramic", date: "early 17th century", objectID: 451800, focalPoint: .init(x: 0.5, y: 0.54), zoom: 2.1),
        .init(id: "butterflies", title: "A cabinet of wings", credit: "Wenceslaus Hollar", medium: "Etching", date: "1625–77", objectID: 361552, focalPoint: .init(x: 0.5, y: 0.48), zoom: 1.8),
        .init(id: "bird", title: "Bird among leaves", credit: "William Morris", medium: "Woven textile", date: "designed 1878", objectID: 221485, focalPoint: .init(x: 0.5, y: 0.38), zoom: 2.1),
        .init(id: "apollo", title: "The Chariot of Apollo", credit: "Odilon Redon", medium: "Oil painting", date: "1905–16", objectID: 437380, focalPoint: .init(x: 0.48, y: 0.38), zoom: 1.8),
        .init(id: "quilt", title: "A thousand small pieces", credit: "Maker unrecorded", medium: "Patchwork quilt", date: "1820–50", objectID: 229936, focalPoint: .init(x: 0.5, y: 0.5), zoom: 2.3),
        .init(id: "glass-face", title: "A face in stained glass", credit: "French", medium: "Stained glass", date: "1200–1215", objectID: 467259, focalPoint: .init(x: 0.5, y: 0.37), zoom: 1.55),
        .init(id: "plum", title: "Flowering Plum Tree", credit: "Utagawa Hiroshige", medium: "Woodblock print", date: "ca. 1843–47", objectID: 56940, focalPoint: .init(x: 0.5, y: 0.61), zoom: 1.6),
        .init(id: "nautilus", title: "A shell made ceremonial", credit: "Friedrich Hillebrand", medium: "Silver and nautilus shell", date: "19th century", objectID: 205691, focalPoint: .init(x: 0.5, y: 0.51), zoom: 2.0),
        .init(id: "daisy", title: "Daisy", credit: "William Morris", medium: "Wallpaper design", date: "1864", objectID: 384017, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.75),
        .init(id: "mosaic", title: "Stone by stone", credit: "Roman", medium: "Roman mosaic", date: "2nd century CE", objectID: 253565, focalPoint: .init(x: 0.52, y: 0.48), zoom: 1.9),
        .init(id: "flowers", title: "Etruscan Vase with Flowers", credit: "Odilon Redon", medium: "Oil painting", date: "1900–1910", objectID: 437381, focalPoint: .init(x: 0.53, y: 0.33), zoom: 1.7),
        .init(id: "dragon", title: "Dragon scales", credit: "China", medium: "Silk robe", date: "18th century", objectID: 70591, focalPoint: .init(x: 0.5, y: 0.55), zoom: 2.25),
        .init(id: "prayers", title: "Ink, gold, and margins", credit: "Hasan 'Ali", medium: "Illuminated manuscript", date: "dated 970 AH/1562–63 CE", objectID: 739852, focalPoint: .init(x: 0.36, y: 0.3), zoom: 1.9),
        .init(id: "porcelain-peacock", title: "Porcelain plumage", credit: "Meissen Manufactory", medium: "Porcelain", date: "1741", objectID: 205629, focalPoint: .init(x: 0.5, y: 0.38), zoom: 1.8),
        .init(id: "pomegranate", title: "Pomegranate", credit: "William Morris", medium: "Wallpaper design", date: "ca. 1866", objectID: 365338, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.7),
        .init(id: "buddha", title: "A quiet stone face", credit: "Cambodia or Vietnam", medium: "Stone sculpture", date: "mid-7th century", objectID: 38160, focalPoint: .init(x: 0.52, y: 0.22), zoom: 2.8),
        .init(id: "iznik", title: "Blue stems, red flowers", credit: "Turkey; maker unrecorded", medium: "Ceramic", date: "16th century", objectID: 934485, focalPoint: .init(x: 0.5, y: 0.45), zoom: 2.2),
        .init(id: "pegasus", title: "Pegasus and Bellerophon", credit: "Odilon Redon", medium: "Charcoal drawing", date: "ca. 1888", objectID: 459400, focalPoint: .init(x: 0.5, y: 0.4), zoom: 1.7),
        .init(id: "hanging", title: "A garden in stitches", credit: "Nurata, present-day Uzbekistan; maker unrecorded", medium: "Silk embroidery", date: "early 19th century", objectID: 444991, focalPoint: .init(x: 0.5, y: 0.5), zoom: 2.0),
        .init(id: "sutra", title: "A small painted universe", credit: "Unidentified artist", medium: "Manuscript painting", date: "11th–12th century", objectID: 821085, focalPoint: .init(x: 0.55, y: 0.59), zoom: 2.05),
    ]
    static var assetNames: [String] { artworks.map(\.id) }

    static func index(at date: Date, offset: Int, context: String) -> Int {
        let text = context.lowercased()
        let topics = [["math", "interactive", "edumation", "builder"], ["boat", "cannes", "travel", "greece"], ["writing", "book", "stikky", "article"]]
        let scores = topics.map { words in words.reduce(0) { $0 + (text.contains($1) ? 1 : 0) } }
        let topic = scores.indices.max { scores[$0] < scores[$1] } ?? 0
        let hour = Int(date.timeIntervalSince1970 / 3600)
        return normalized(hour % artworks.count + offset % artworks.count + topic)
    }
    static func offset(selecting selected: Int, at date: Date, context: String) -> Int {
        normalized(selected - index(at: date, offset: 0, context: context))
    }
    private static func normalized(_ value: Int) -> Int { (value % artworks.count + artworks.count) % artworks.count }

    // Keep the focal point near the center, clamping at the image edges so no gaps appear.
    static func cropFrame(image: CGSize, viewport: CGSize, focalPoint: CGPoint, zoom: CGFloat = 1) -> CGRect {
        guard image.width > 0, image.height > 0, viewport.width > 0, viewport.height > 0 else { return .zero }
        let scale = max(viewport.width / image.width, viewport.height / image.height) * max(1, zoom)
        let width = image.width * scale, height = image.height * scale
        let x = min(0, max(viewport.width - width, viewport.width / 2 - focalPoint.x * width))
        let y = min(0, max(viewport.height - height, viewport.height / 2 - focalPoint.y * height))
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

/// The resource location is a value dependency, so previews never mutate live globals.
private struct ArtResourceRootKey: EnvironmentKey {
    static let defaultValue: URL? = Bundle.main.resourceURL
}
extension EnvironmentValues {
    var artResourceRoot: URL? {
        get { self[ArtResourceRootKey.self] }
        set { self[ArtResourceRootKey.self] = newValue }
    }
}

@MainActor final class ArtImageLoader {
    static let shared = ArtImageLoader()
    // Decode just the current artwork, never the whole library at full resolution.
    private let fullImages = ArtImageLoader.cache(count: 3, bytes: 48 * 1024 * 1024)
    private let thumbnails = ArtImageLoader.cache(count: 24, bytes: 24 * 1024 * 1024)
    private static func cache(count: Int, bytes: Int) -> NSCache<NSString, NSImage> {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = count; cache.totalCostLimit = bytes
        return cache
    }
    func image(for artwork: BackdropArtwork, thumbnail: Bool = false, resourceRoot: URL? = Bundle.main.resourceURL) -> NSImage? {
        guard let url = resourceRoot?.appendingPathComponent("Art/\(artwork.filename)") else { return nil }
        let cache = thumbnail ? thumbnails : fullImages
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: thumbnail ? Int(ceil(400 * artwork.zoom)) : 2048,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        // Preserve the artwork's original color; only downsample the decoded display copy.
        let result = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        cache.setObject(result, forKey: key, cost: image.bytesPerRow * image.height)
        return result
    }

}

struct ArtDetail: View {
    @Environment(\.artResourceRoot) private var resourceRoot
    let artwork: BackdropArtwork
    var thumbnail = false
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                if let image = ArtImageLoader.shared.image(for: artwork, thumbnail: thumbnail, resourceRoot: resourceRoot) {
                    let frame = ArtBackdrop.cropFrame(image: image.size, viewport: proxy.size, focalPoint: artwork.focalPoint, zoom: artwork.zoom)
                    Image(nsImage: image).resizable()
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                }
            }.clipped()
        }
    }
}

struct BoardBackdrop: View {
    let appearance: BoardAppearance
    let artOffset: Int
    let context: String
    var body: some View {
        if appearance.theme == .art {
            TimelineView(.periodic(from: .now, by: 60)) { tick in
                ZStack {
                    ArtDetail(artwork: ArtBackdrop.artworks[ArtBackdrop.index(at: tick.date, offset: artOffset, context: context)])
                    LinearGradient(colors: [.black.opacity(0.6), .black.opacity(0.08), .black.opacity(0.28)], startPoint: .top, endPoint: .bottom)
                }
            }.accessibilityHidden(true).allowsHitTesting(false)
        } else { appearance.canvas }
    }
}

struct ArtLibraryView: View {
    @Binding var artOffset: Int
    let context: String
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Int

    init(artOffset: Binding<Int>, context: String) {
        _artOffset = artOffset
        self.context = context
        _selected = State(initialValue: ArtBackdrop.index(at: .now, offset: artOffset.wrappedValue, context: context))
    }
    private var artwork: BackdropArtwork { ArtBackdrop.artworks[selected] }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Art, up close").font(.system(size: 21, weight: .semibold, design: .serif))
                    Text("\(ArtBackdrop.artworks.count) art details · a new one each hour").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 24, height: 24) }
                    .buttonStyle(.plain).accessibilityLabel("Close art library").keyboardShortcut(.cancelAction)
            }
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 14) {
                        ForEach(Array(ArtBackdrop.artworks.enumerated()), id: \.element.id) { index, item in
                            Button {
                                selected = index
                                artOffset = ArtBackdrop.offset(selecting: index, at: .now, context: context)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    ArtDetail(artwork: item, thumbnail: true)
                                        .frame(height: 184)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(alignment: .topTrailing) {
                                            if selected == index {
                                                Image(systemName: "checkmark.circle.fill").font(.system(size: 17))
                                                    .foregroundStyle(.black, .white).padding(7)
                                            }
                                        }
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(selected == index ? 0.9 : 0.12), lineWidth: selected == index ? 2 : 1))
                                    Text(item.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel(item.title + (selected == index ? ", selected" : ""))
                                .help("Use \(item.title)").id(index)
                        }
                    }.padding(2)
                }.onAppear { scroll.scrollTo(selected, anchor: .center) }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(artwork.title).font(.system(size: 12, weight: .semibold))
                Text(artwork.credit).font(.system(size: 11))
                Text(artwork.license).font(.system(size: 10)).foregroundStyle(.secondary)
                Text("\(artwork.date) · \(artwork.medium)").font(.system(size: 10)).foregroundStyle(.secondary)
                Link("Explore the whole artwork ↗", destination: artwork.source).font(.system(size: 11)).tint(.white)
            }.frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        }.padding(18).frame(width: 340, height: 570)
            .foregroundStyle(.white).background(Color(hex: 0x17191C))
            .environment(\.colorScheme, .dark)
    }
}
