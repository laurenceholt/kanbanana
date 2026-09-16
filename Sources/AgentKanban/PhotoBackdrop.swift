import KanbananaCore
import AppKit
import ImageIO
import SwiftUI

struct BackdropPhoto: Identifiable {
    let id: String
    let title: String
    let filename: String
    let credit: String
    let license: String
    let recognition: String
    let source: URL?
    var focalPoint = CGPoint(x: 0.5, y: 0.5)

    static func generated(_ id: String, _ title: String) -> Self {
        .init(id: id, title: title, filename: "\(id).png", credit: "Created for kanbanana", license: "AI-generated photograph", recognition: "", source: nil)
    }
    static func sourced(_ id: String, _ title: String, _ author: String, _ license: String, _ file: String,
                        recognition: String = "Wikimedia Commons Featured Picture", focalPoint: CGPoint = .init(x: 0.5, y: 0.5)) -> Self {
        .init(id: id, title: title, filename: "\(id).jpg", credit: author, license: license, recognition: recognition,
              source: URL(string: "https://commons.wikimedia.org/wiki/File:" + file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!), focalPoint: focalPoint)
    }
}

enum PhotoBackdrop {
    // Interleave animals, architecture, oddities and landscapes so each hour feels different.
    static let photos: [BackdropPhoto] = [
        .generated("geometry", "Quiet geometry"),
        .generated("puppy", "A very good question"),
        .sourced("earthrise", "Earthrise, 1968", "William Anders / NASA", "Public domain · US federal work", "AS08-13-2329.jpg", focalPoint: .init(x: 0.626, y: 0.49)),
        .generated("chair", "Reserved for nobody"),
        .generated("harbor", "Before the harbor wakes"),
        .generated("owl", "Just checking"),
        .sourced("leaves", "Leaves, Glacier National Park", "Ansel Adams / National Park Service", "Public domain · US federal work", "Ansel_Adams_-_National_Archives_79-AA-E23.jpg"),
        .generated("balloon", "A second moon"),
        .sourced("lightning", "Lightning over Oradea", "Mircea Madau · edit by Diego pmc", "Public domain · released by the photographer", "Lightning_over_Oradea_Romania_3.jpg", recognition: "Wikipedia Featured Picture"),
        .generated("horse", "Out of the mist"),
        .generated("pages", "Paper landscape"),
        .sourced("moonwalk", "A walk on the Moon", "Neil Armstrong / NASA", "Public domain · US federal work", "Aldrin_Apollo_11.jpg"),
        .generated("snail", "Taking the long way"),
        .sourced("tetons", "The Tetons and the Snake River", "Ansel Adams / US Department of the Interior", "Public domain · US federal work", "Adams_The_Tetons_and_the_Snake_River.jpg"),
        .generated("telephone", "Please hold"),
        .sourced("medusa", "Lion’s mane", "W.carter", "CC0 1.0 · public domain dedication", "Lion's_mane_jellyfish_in_Gullmarn_fjord_at_Sämstad_3.jpg", recognition: "Picture of the Year 2019 finalist · Commons Featured Picture", focalPoint: .init(x: 0.34, y: 0.5)),
        .generated("umbrella", "A little unprepared"),
        .generated("jellyfish", "A small ghost")
    ]
    static var assetNames: [String] { photos.map(\.id) }

    static func index(at date: Date, offset: Int, context: String) -> Int {
        let text = context.lowercased()
        let topics = [["math", "interactive", "edumation", "builder"], ["boat", "cannes", "travel", "greece"], ["writing", "book", "stikky", "article"]]
        let scores = topics.map { words in words.reduce(0) { $0 + (text.contains($1) ? 1 : 0) } }
        let topic = scores.indices.max { scores[$0] < scores[$1] } ?? 0
        let hour = Int(date.timeIntervalSince1970 / 3600)
        return normalized(hour % photos.count + offset % photos.count + topic)
    }
    static func offset(selecting selected: Int, at date: Date, context: String) -> Int {
        normalized(selected - index(at: date, offset: 0, context: context))
    }
    private static func normalized(_ value: Int) -> Int { (value % photos.count + photos.count) % photos.count }

    // Keep the focal point near the center, clamping at the image edges so no gaps appear.
    static func cropFrame(image: CGSize, viewport: CGSize, focalPoint: CGPoint) -> CGRect {
        guard image.width > 0, image.height > 0, viewport.width > 0, viewport.height > 0 else { return .zero }
        let scale = max(viewport.width / image.width, viewport.height / image.height)
        let width = image.width * scale, height = image.height * scale
        let x = min(0, max(viewport.width - width, viewport.width / 2 - focalPoint.x * width))
        let y = min(0, max(viewport.height - height, viewport.height / 2 - focalPoint.y * height))
        return CGRect(x: x, y: y, width: width, height: height)
    }
}

/// The resource location is a value dependency, so previews never mutate live globals.
private struct PhotoResourceRootKey: EnvironmentKey {
    static let defaultValue: URL? = Bundle.main.resourceURL
}
extension EnvironmentValues {
    var photoResourceRoot: URL? {
        get { self[PhotoResourceRootKey.self] }
        set { self[PhotoResourceRootKey.self] = newValue }
    }
}

@MainActor final class PhotoImageLoader {
    static let shared = PhotoImageLoader()
    // Decode just the current photograph, never the whole library at full resolution.
    private let fullImages = PhotoImageLoader.cache(count: 3, bytes: 48 * 1024 * 1024)
    private let thumbnails = PhotoImageLoader.cache(count: 24, bytes: 10 * 1024 * 1024)
    private static func cache(count: Int, bytes: Int) -> NSCache<NSString, NSImage> {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = count; cache.totalCostLimit = bytes
        return cache
    }
    func image(for photo: BackdropPhoto, thumbnail: Bool = false, resourceRoot: URL? = Bundle.main.resourceURL) -> NSImage? {
        guard let url = resourceRoot?.appendingPathComponent("Photos/\(photo.filename)") else { return nil }
        let cache = thumbnail ? thumbnails : fullImages
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: thumbnail ? 400 : 2048,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { return nil }
        // Convert the decoded display copy; the bundled source photograph stays untouched.
        guard let gray = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                   bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        gray.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let monochrome = gray.makeImage() else { return nil }
        let result = NSImage(cgImage: monochrome, size: NSSize(width: image.width, height: image.height))
        cache.setObject(result, forKey: key, cost: monochrome.bytesPerRow * monochrome.height)
        return result
    }

}

struct CroppedPhotograph: View {
    @Environment(\.photoResourceRoot) private var resourceRoot
    let photo: BackdropPhoto
    var thumbnail = false
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                if let image = PhotoImageLoader.shared.image(for: photo, thumbnail: thumbnail, resourceRoot: resourceRoot) {
                    let frame = PhotoBackdrop.cropFrame(image: image.size, viewport: proxy.size, focalPoint: photo.focalPoint)
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
    let photoOffset: Int
    let context: String
    var body: some View {
        if appearance.theme == .photos {
            TimelineView(.periodic(from: .now, by: 60)) { tick in
                ZStack {
                    CroppedPhotograph(photo: PhotoBackdrop.photos[PhotoBackdrop.index(at: tick.date, offset: photoOffset, context: context)])
                    LinearGradient(colors: [.black.opacity(0.65), .black.opacity(0.12), .black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
                }
            }.accessibilityHidden(true).allowsHitTesting(false)
        } else { appearance.canvas }
    }
}

struct PhotoLibraryView: View {
    @Binding var photoOffset: Int
    let context: String
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Int

    init(photoOffset: Binding<Int>, context: String) {
        _photoOffset = photoOffset
        self.context = context
        _selected = State(initialValue: PhotoBackdrop.index(at: .now, offset: photoOffset.wrappedValue, context: context))
    }
    private var photo: BackdropPhoto { PhotoBackdrop.photos[selected] }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Photo library").font(.system(size: 21, weight: .semibold, design: .serif))
                    Text("\(PhotoBackdrop.photos.count) photographs · a new one each hour").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").frame(width: 24, height: 24) }
                    .buttonStyle(.plain).accessibilityLabel("Close photo library").keyboardShortcut(.cancelAction)
            }
            ScrollViewReader { scroll in
                ScrollView {
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 14) {
                        ForEach(Array(PhotoBackdrop.photos.enumerated()), id: \.element.id) { index, item in
                            Button {
                                selected = index
                                photoOffset = PhotoBackdrop.offset(selecting: index, at: .now, context: context)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    CroppedPhotograph(photo: item, thumbnail: true)
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
                Text(photo.title).font(.system(size: 12, weight: .semibold))
                Text(photo.credit).font(.system(size: 11))
                Text(photo.license).font(.system(size: 10)).foregroundStyle(.secondary)
                if !photo.recognition.isEmpty { Text(photo.recognition).font(.system(size: 10)).foregroundStyle(.secondary) }
                if let source = photo.source { Link("Source & license ↗", destination: source).font(.system(size: 11)).tint(.white) }
            }.frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        }.padding(18).frame(width: 340, height: 570)
            .foregroundStyle(.white).background(Color(hex: 0x17191C))
            .environment(\.colorScheme, .dark)
    }
}
