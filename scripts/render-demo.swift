import AppKit
import AVFoundation
import SwiftUI
import KanbananaCore
import KanbananaServices

/// One persistent real app view, driven through its own controls. Never captures the desktop.
@main struct RenderDemo {
    @MainActor static func main() async throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("kanbanana-film-" + UUID().uuidString)
        let preferences = UserDefaults(suiteName: root.lastPathComponent)!
        defer {
            preferences.removePersistentDomain(forName: root.lastPathComponent)
            try? FileManager.default.removeItem(at: root)
        }
        preferences.set(BoardLayout.focus.rawValue, forKey: "boardLayout")
        preferences.set(BoardTheme.night.rawValue, forKey: BoardTheme.preferenceKey)
        let state = DemoData.state(mode: "focus", priority: false)
        let store = await BoardStore.loaded(root: root, start: false, initialState: state,
            credentials: DemoCredentials(), summarize: { _, _, _ in throw DemoCredentials.Disabled() })
        DemoData.showHealth(in: store)
        let style = BoardAppearance(background: .butter, cards: .cream, theme: .night)
        let host = NSHostingView(rootView: BoardView(store: store, layoutPreferences: preferences)
            .environment(\.boardAppearance, style).environment(\.colorScheme, .dark))
        let window = DemoWindow(contentRect: NSRect(x: 0, y: 0, width: 390, height: 610),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
        window.orderFrontRegardless()
        window.makeKey()
        defer { window.orderOut(nil) }
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(300))
        func scrollView(_ view: NSView) -> NSScrollView? {
            if let scroll = view as? NSScrollView, scroll.hasVerticalScroller { return scroll }
            for child in view.subviews { if let scroll = scrollView(child) { return scroll } }
            return nil
        }
        func click(_ point: CGPoint) {
            for type: NSEvent.EventType in [.leftMouseDown, .leftMouseUp] {
                let event = NSEvent.mouseEvent(with: type, location: CGPoint(x: point.x, y: host.bounds.height - point.y),
                    modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
                window.sendEvent(event)
            }
        }
        let captions: [(Double, Double, String)] = [
            (0, 4, "This is kanbanana. I keep it beside\nwhatever I’m working on."),
            (4, 8, "It brings my Claude Code and Codex\ndesktop work into one little window."),
            (8, 12, "Up here: what’s running, what needs me,\nand what’s ready to check."),
            (12, 16, "I can scroll through the replies\nwithout losing track of things."),
            (16, 20, "Each card gives me a short version\nof what the agent reported."),
            (20, 24, "Click a conversation to open it\nin Claude or Codex."),
            (24, 28, "If something matters most, I star it.\nIt stays at the top."),
            (28, 32, "Once I’ve looked at it, I click here\nto mark it Dealt with."),
            (32, 36, "It leaves this list. A new request\nwill bring it back."),
            (36, 40, "And when I want the bigger picture,\nI expand to Projects."),
            (40, 46, "The conversations stay separate,\nbut now they’re grouped by project."),
            (46, 52, "These little notes remind me\nwhat I’m trying to get done.")
        ]
        let manifest = captions.map { ["start": $0.0, "end": $0.1, "caption": $0.2] as [String: Any] }
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            .write(to: output.appendingPathComponent("captions.json"))
        let videoURL = output.appendingPathComponent("walkthrough-silent.mp4")
        try? FileManager.default.removeItem(at: videoURL)
        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 1080, AVVideoHeightKey: 1920,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 4_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel]])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: 1080, kCVPixelBufferHeightKey as String: 1920,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? FilmError.encode }
        writer.startSession(atSourceTime: .zero)
        let notes = store.cards.first { $0.title == "Polish release notes" }!
        let focusScroll = scrollView(host)!
        let fps = 30
        let start = ContinuousClock.now
        var cachedView: CGImage?
        var priorityChecked = false, dealtChecked = false, projectsChecked = false
        var cursor = CGPoint(x: 360, y: 560)
        let keyframes: [(Double, CGPoint)] = [
            (0, CGPoint(x: 360, y: 560)), (7.8, CGPoint(x: 360, y: 560)),
            (8.5, CGPoint(x: 120, y: 66)), (9.4, CGPoint(x: 195, y: 66)),
            (10.4, CGPoint(x: 270, y: 66)), (11.5, CGPoint(x: 350, y: 390)),
            (19, CGPoint(x: 350, y: 390)), (21, CGPoint(x: 160, y: 168)),
            (23.8, CGPoint(x: 160, y: 168)), (24.8, CGPoint(x: 343, y: 290)),
            (25.5, CGPoint(x: 343, y: 290)), (26.4, CGPoint(x: 343, y: 139)),
            (28.5, CGPoint(x: 343, y: 139)), (29.6, CGPoint(x: 342, y: 241)),
            (31, CGPoint(x: 342, y: 241)), (33, CGPoint(x: 346, y: 66)),
            (35.8, CGPoint(x: 346, y: 66)), (37.2, CGPoint(x: 366, y: 97)),
            (39, CGPoint(x: 366, y: 97)), (41, CGPoint(x: 460, y: 140)),
            (46, CGPoint(x: 460, y: 140)), (47, CGPoint(x: 240, y: 180)),
            (52, CGPoint(x: 240, y: 180))
        ]
        func smooth(_ x: Double) -> Double { let x = min(1, max(0, x)); return x * x * (3 - 2 * x) }
        for frame in 0..<(52 * fps) {
            let t = Double(frame) / Double(fps)
            if frame == 25 * fps { click(CGPoint(x: 343, y: 290)); print("Clicked priority") }
            if frame == 30 * fps { click(CGPoint(x: 342, y: 241)); print("Clicked Dealt with") }
            if frame == 38 * fps { click(CGPoint(x: 366, y: 97)); print("Clicked Projects") }
            if t >= 38 {
                let progress = smooth((t - 38) / 1.2)
                let width = 390 + 450 * progress
                window.setContentSize(CGSize(width: width, height: width * 610 / 390))
            } else if t >= 12 && t < 24 {
                let down = smooth((t - 12) / 3)
                let up = smooth((t - 18) / 3)
                focusScroll.contentView.scroll(to: CGPoint(x: 0, y: 390 * (down - up)))
                focusScroll.reflectScrolledClipView(focusScroll.contentView)
            }
            // Advance the real run loop so SwiftUI input, scrolling and animations settle naturally.
            let deadline = start.advanced(by: .seconds(Double(frame + 1) / Double(fps)))
            if ContinuousClock.now < deadline { try await Task.sleep(until: deadline, clock: .continuous) }
            else { try await Task.sleep(for: .milliseconds(1)) }
            host.layoutSubtreeIfNeeded()
            if t > 26 && !priorityChecked {
                guard store.focusCards(in: .ready).first?.id == notes.id else { throw FilmError.priority }
                priorityChecked = true
            }
            if t > 31 && !dealtChecked {
                guard store.column(notes) == .dealtWith && store.focusCards(in: .ready).count == 5 else { throw FilmError.dealt }
                dealtChecked = true
            }
            if t > 40 && !projectsChecked {
                guard preferences.string(forKey: "boardLayout") == BoardLayout.projects.rawValue else { throw FilmError.projects }
                projectsChecked = true
            }
            let segment = zip(keyframes, keyframes.dropFirst()).first { t >= $0.0.0 && t <= $0.1.0 }!
            let p = smooth((t - segment.0.0) / (segment.1.0 - segment.0.0))
            cursor = CGPoint(x: segment.0.1.x + (segment.1.1.x - segment.0.1.x) * p,
                             y: segment.0.1.y + (segment.1.1.y - segment.0.1.y) * p)
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(2)) }
            var buffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer) == kCVReturnSuccess,
                  let buffer else { throw FilmError.encode }
            CVPixelBufferLockBaseAddress(buffer, [])
            let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: 1080, height: 1920,
                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
            context.setFillColor(CGColor(gray: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 1080, height: 1920))
            // Reuse pixels during still holds; always refresh scrolling, real UI transitions and resizing.
            // The native view remains alive throughout; this avoids repeatedly rasterizing a tall board.
            let moving = (12...21).contains(t) || (25...26).contains(t) || (30...31).contains(t) || (38...40).contains(t)
            if cachedView == nil || moving || frame % fps == 0 {
                guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw FilmError.render }
                host.cacheDisplay(in: host.bounds, to: rep)
                cachedView = rep.cgImage
            }
            let scale = 1080 / host.bounds.width
            let appHeight = host.bounds.height * scale
            context.interpolationQuality = .high
            context.draw(cachedView!, in: CGRect(x: 0, y: 1920 - appHeight, width: 1080, height: appHeight))
            // Visible pointer and restrained click ring; coordinates match the actual dispatched events.
            context.saveGState()
            context.translateBy(x: cursor.x * scale, y: 1920 - cursor.y * scale)
            let cursorScale = t < 38 ? 2.2 : 1.6
            context.scaleBy(x: cursorScale, y: -cursorScale)
            context.move(to: .zero); context.addLine(to: CGPoint(x: 0, y: 18))
            context.addLine(to: CGPoint(x: 5, y: 14)); context.addLine(to: CGPoint(x: 9, y: 23))
            context.addLine(to: CGPoint(x: 13, y: 21)); context.addLine(to: CGPoint(x: 9, y: 13))
            context.addLine(to: CGPoint(x: 16, y: 13)); context.closePath()
            context.setFillColor(CGColor(gray: 1, alpha: 1)); context.setStrokeColor(CGColor(gray: 0, alpha: 1))
            context.setLineWidth(1); context.drawPath(using: .fillStroke)
            context.restoreGState()
            for clickTime in [25.0, 30.0, 38.0] where t >= clickTime && t < clickTime + 0.45 {
                let age = (t - clickTime) / 0.45
                let r = 16 + age * 25
                context.setStrokeColor(CGColor(red: 1, green: 0.88, blue: 0.24, alpha: 1 - age))
                context.setLineWidth(3)
                context.strokeEllipse(in: CGRect(x: cursor.x * scale - r, y: 1920 - cursor.y * scale - r, width: r * 2, height: r * 2))
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
            let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineSpacing = 10
            let caption = captions.first { t >= $0.0 && t < $0.1 }!.2
            (caption as NSString).draw(in: NSRect(x: 38, y: 71, width: 1004, height: 132), withAttributes: [
                .font: NSFont.systemFont(ofSize: 42, weight: .medium), .foregroundColor: NSColor.white, .paragraphStyle: paragraph])
            ("Fictional sessions · desktop workflow" as NSString).draw(in: NSRect(x: 30, y: 24, width: 1020, height: 30), withAttributes: [
                .font: NSFont.systemFont(ofSize: 22), .foregroundColor: NSColor(white: 0.55, alpha: 1), .paragraphStyle: paragraph])
            NSGraphicsContext.restoreGraphicsState()
            if [0, 15*fps, 26*fps, 31*fps, 40*fps, 49*fps].contains(frame) {
                let image = NSBitmapImageRep(cgImage: context.makeImage()!)
                try image.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("check-\(Int(t)).png"))
                print("Captured \(Int(t))s")
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: Int32(fps))) else {
                throw writer.error ?? FilmError.encode
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? FilmError.encode }
        await store.stop()
        print("Verified real UI clicks: priority, Dealt with, Projects; recorded one continuous 52s view.")
    }
    enum FilmError: Error { case encode, render, priority, dealt, projects }
}
private final class DemoWindow: NSWindow { override var canBecomeKey: Bool { true } }
