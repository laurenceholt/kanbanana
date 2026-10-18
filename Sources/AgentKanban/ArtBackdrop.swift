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
    let filename: String
    let license: String
    let imageCredit: String
    let source: URL
    let article: URL
    var focalPoint = CGPoint(x: 0.5, y: 0.5)
    var zoom: CGFloat = 1
    var caption: String { "\(title) — \(credit), \(date)" }
}

enum ArtBackdrop {
    // Contemporary artists’ work with artist releases or documented Commons permissions.
    // Resources/Art/catalog.json records provenance, license and permission evidence.
    static let artworks: [BackdropArtwork] = [
        .init(id: "searching-void", title: "Searching the Void", credit: "Todd Williamson",
              medium: "Oil on canvas", date: "2016", filename: "searching-void.jpg", license: "CC BY-SA 4.0", imageCredit: "Todd Williamson",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Todd_WILLIAMSON,_Searching_the_Void_(36x48in),_Oil_on_canvas_(2016).jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Todd_WILLIAMSON,_Searching_the_Void_(36x48in),_Oil_on_canvas_(2016).jpg")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.05),
        .init(id: "mandril", title: "Mandril en ágape", credit: "José de Martín Simón",
              medium: "Painting", date: "2013", filename: "mandril.jpg", license: "CC BY-SA 3.0", imageCredit: "José de Martín Simón",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Mandril_en_%C3%A1gape.jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Mandril_en_%C3%A1gape.jpg")!, focalPoint: .init(x: 0.62, y: 0.42), zoom: 1),
        .init(id: "bearable-lights", title: "Bearable Lights", credit: "Ben Vollers & Fons Heijnsbroek",
              medium: "Acrylic on canvas", date: "2007", filename: "bearable-lights.jpg", license: "CC0", imageCredit: "Ben Vollers & Fons Heijnsbroek",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:%27Bearable_Lights%27_-_abstract_painting_on_canvas_in_blue_and_yellow_strokes,_fusion_art_by_Dutch_artists_Ben_Vollers_%26_Fons_Heijnsbroek,_2007;_modern_abstract_expressionism_-_free_download_image_CC0,_high_resolutions_TIFF.tif")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:%27Bearable_Lights%27_-_abstract_painting_on_canvas_in_blue_and_yellow_strokes,_fusion_art_by_Dutch_artists_Ben_Vollers_%26_Fons_Heijnsbroek,_2007;_modern_abstract_expressionism_-_free_download_image_CC0,_high_resolutions_TIFF.tif")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.05),
        .init(id: "enigma", title: "Enigma", credit: "Peter Klashorst",
              medium: "Painting", date: "Undated", filename: "enigma.jpg", license: "CC BY 2.0", imageCredit: "Peter Klashorst",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Enigma_(painting_by_Peter_Klashorst).jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Enigma_(painting_by_Peter_Klashorst).jpg")!, focalPoint: .init(x: 0.45, y: 0.44), zoom: 1),
        .init(id: "creating-mischief", title: "Creating Mischief", credit: "Todd Williamson",
              medium: "Oil on canvas", date: "2016", filename: "creating-mischief.jpg", license: "CC BY-SA 4.0", imageCredit: "Todd Williamson",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Todd_WILLIAMSON,_Creating_Mischief_(60x60in),_Oil_on_canvas_(2016).jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Todd_WILLIAMSON,_Creating_Mischief_(60x60in),_Oil_on_canvas_(2016).jpg")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1),
        .init(id: "barroco", title: "Barroco", credit: "José de Martín Simón",
              medium: "Mixed-media artwork", date: "Undated", filename: "barroco.jpg", license: "CC BY-SA 3.0", imageCredit: "José de Martín Simón",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Barroco_martin_simon.jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Barroco_martin_simon.jpg")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.05),
        .init(id: "colored-figures", title: "Colored figures", credit: "Fons Heijnsbroek",
              medium: "Gouache on paper", date: "2012", filename: "colored-figures.jpg", license: "CC0", imageCredit: "Fons Heijnsbroek",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Abstract_gouache_painting_%27Colored_figures%27_-_watercolor_art_on_paper,_made_in_2012_by_Dutch_painter_artist_Fons_Heijnsbroek.tif")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Abstract_gouache_painting_%27Colored_figures%27_-_watercolor_art_on_paper,_made_in_2012_by_Dutch_painter_artist_Fons_Heijnsbroek.tif")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.05),
        .init(id: "gentlemans-club", title: "The Gentleman’s Club", credit: "Marike Bok",
              medium: "Painting", date: "1995", filename: "gentlemans-club.jpg", license: "CC BY-SA 3.0", imageCredit: "Marike Bok",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:The_Gentleman%27s_Club_(De_Heren_club)_Painted_by_Marike_Bok.jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:The_Gentleman%27s_Club_(De_Heren_club)_Painted_by_Marike_Bok.jpg")!, focalPoint: .init(x: 0.52, y: 0.45), zoom: 1.05),
        .init(id: "counting-forever", title: "Counting on Forever", credit: "Todd Williamson",
              medium: "Oil on canvas", date: "2016", filename: "counting-forever.jpg", license: "CC BY-SA 4.0", imageCredit: "Todd Williamson",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Todd_WILLIAMSON,_Counting_on_Forever_(70x60in),_Oil_on_canvas_(2016).jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Todd_WILLIAMSON,_Counting_on_Forever_(70x60in),_Oil_on_canvas_(2016).jpg")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1),
        .init(id: "medusa", title: "Medusa voladora", credit: "José de Martín Simón",
              medium: "Painting", date: "2013", filename: "medusa.jpg", license: "CC BY-SA 3.0", imageCredit: "José de Martín Simón",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Medusa_voladora.jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Medusa_voladora.jpg")!, focalPoint: .init(x: 0.36, y: 0.42), zoom: 1),
        .init(id: "no-4106", title: "No. 4.106", credit: "Fons Heijnsbroek",
              medium: "Acrylic on canvas", date: "2006", filename: "no-4106.jpg", license: "CC0", imageCredit: "Fons Heijnsbroek",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Abstract_large_painting_%27no._4.106%27_-_in_acrylic_diagonal_brush_strokes_on_canvas,_by_Dutch_artist_Fons_Heijnsbroek,_2006;_free_download_art_image_CC0;_photo_in_high_resolutions.jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Abstract_large_painting_%27no._4.106%27_-_in_acrylic_diagonal_brush_strokes_on_canvas,_by_Dutch_artist_Fons_Heijnsbroek,_2006;_free_download_art_image_CC0;_photo_in_high_resolutions.jpg")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1),
        .init(id: "tiny-buddha", title: "Tiny Buddha", credit: "Todd Williamson",
              medium: "Oil on canvas", date: "2016", filename: "tiny-buddha.jpg", license: "CC BY-SA 4.0", imageCredit: "Todd Williamson",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Todd_WILLIAMSON,_Tiny_Buddha_(50x50in),_Oil_on_canvas_(2016).jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Todd_WILLIAMSON,_Tiny_Buddha_(50x50in),_Oil_on_canvas_(2016).jpg")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.05),
        .init(id: "desde-cueva", title: "Desde la cueva", credit: "José de Martín Simón",
              medium: "Painting", date: "2016", filename: "desde-cueva.jpg", license: "CC BY-SA 3.0", imageCredit: "José de Martín Simón",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Desde_la_cueva.jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Desde_la_cueva.jpg")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.05),
        .init(id: "danish-blue", title: "Danish Blue", credit: "Ben Vollers & Fons Heijnsbroek",
              medium: "Acrylic on canvas", date: "2008", filename: "danish-blue.jpg", license: "CC0", imageCredit: "Ben Vollers & Fons Heijnsbroek",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:%27Danish_Blue%27_large_abstract_painting_on_canvas,_created_together_by_artists_Ben_Vollers_%26_Fons_Heijnsbroek_in_2008;_modern_wall_art_painting_-_free_download_art_image_CC0,_high_resolutions_TIFF.tif")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:%27Danish_Blue%27_large_abstract_painting_on_canvas,_created_together_by_artists_Ben_Vollers_%26_Fons_Heijnsbroek_in_2008;_modern_wall_art_painting_-_free_download_art_image_CC0,_high_resolutions_TIFF.tif")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.05),
        .init(id: "people-rocks", title: "People Throw Rocks", credit: "Todd Williamson",
              medium: "Oil on canvas", date: "2016", filename: "people-rocks.jpg", license: "CC BY-SA 4.0", imageCredit: "Todd Williamson",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Todd_WILLIAMSON,_People_Throw_Rocks_(83x57in),_Oil_on_canvas_(2016).jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Todd_WILLIAMSON,_People_Throw_Rocks_(83x57in),_Oil_on_canvas_(2016).jpg")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1),
        .init(id: "monje", title: "Monje ocasiano", credit: "José de Martín Simón",
              medium: "Painting", date: "2013", filename: "monje.jpg", license: "CC BY-SA 3.0", imageCredit: "José de Martín Simón",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Monje_ocasiano.jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Monje_ocasiano.jpg")!, focalPoint: .init(x: 0.44, y: 0.5), zoom: 1),
        .init(id: "city-look", title: "City Look 3.", credit: "Fons Heijnsbroek",
              medium: "Acrylic on canvas", date: "2006", filename: "city-look.jpg", license: "CC0", imageCredit: "Fons Heijnsbroek",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Abstract_painting_%27City_Look_3.%27_-_line_painting_in_acrylic_on_canvas_with_brush_textures,_by_Dutch_artist_Fons_Heijnsbroek,_2006;_free_download_art_image_CC0;_photo_in_high_resolutions.tif")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Abstract_painting_%27City_Look_3.%27_-_line_painting_in_acrylic_on_canvas_with_brush_textures,_by_Dutch_artist_Fons_Heijnsbroek,_2006;_free_download_art_image_CC0;_photo_in_high_resolutions.tif")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.05),
        .init(id: "another-reason", title: "Another Reason", credit: "Todd Williamson",
              medium: "Oil on canvas", date: "2014", filename: "another-reason.jpg", license: "CC BY-SA 4.0", imageCredit: "Todd Williamson",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Todd_WILLIAMSON,_Another_Reason_(36x64in),_Oil_on_canvas_(2014).jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Todd_WILLIAMSON,_Another_Reason_(36x64in),_Oil_on_canvas_(2014).jpg")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.05),
        .init(id: "gruta", title: "Gruta esmeralda", credit: "José de Martín Simón",
              medium: "Mixed-media artwork", date: "Undated", filename: "gruta.jpg", license: "CC BY-SA 3.0", imageCredit: "José de Martín Simón",
              source: URL(string: "https://commons.wikimedia.org/wiki/File:Gruta_esmeralda.jpg")!,
              article: URL(string: "https://commons.wikimedia.org/wiki/File:Gruta_esmeralda.jpg")!, focalPoint: .init(x: 0.5, y: 0.5), zoom: 1.05)
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
    let artwork: BackdropArtwork?
    var body: some View {
        if let artwork {
            ZStack {
                ArtDetail(artwork: artwork)
                LinearGradient(colors: [.black.opacity(0.6), .black.opacity(0.08), .black.opacity(0.28)], startPoint: .top, endPoint: .bottom)
            }.accessibilityHidden(true).allowsHitTesting(false)
        } else { appearance.canvas }
    }
}

/// The caller passes the same artwork to the backdrop and this caption, including at hour rollover.
struct ArtworkCaption: View {
    let artwork: BackdropArtwork
    let compact: Bool
    var body: some View {
        Link(destination: artwork.article) {
            Group {
                if compact {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(artwork.title + " ↗").font(.system(size: 10, weight: .medium)).lineLimit(1)
                        Text("\(artwork.credit) · \(artwork.date)").font(.system(size: 9)).foregroundStyle(.white.opacity(0.72)).lineLimit(1)
                    }
                } else {
                    Text(artwork.caption + " ↗").font(.system(size: 10)).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, compact ? 12 : 18).padding(.vertical, 6)
            .foregroundStyle(.white.opacity(0.9))
            .background(.black.opacity(0.78))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityLabel("About the background: " + artwork.caption)
            .help(artwork.caption + " — open artwork page")
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
                if !artwork.imageCredit.isEmpty { Text(artwork.imageCredit).font(.system(size: 10)).foregroundStyle(.secondary) }
                Text("\(artwork.date) · \(artwork.medium)").font(.system(size: 10)).foregroundStyle(.secondary)
                HStack {
                    Link("About this work ↗", destination: artwork.article)
                    Spacer()
                    Link("Image & license ↗", destination: artwork.source)
                }.font(.system(size: 11)).tint(.white)
            }.frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        }.padding(18).frame(width: 340, height: 570)
            .foregroundStyle(.white).background(Color(hex: 0x17191C))
            .environment(\.colorScheme, .dark)
    }
}
