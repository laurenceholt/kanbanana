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
        let window = DemoWindow(contentRect: NSRect(x: 0, y: 0, width: 390, height: 680),
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
            (0, 4, "Keep your agents\nin one small window."),
            (4, 8, "Claude Code + Codex,\nin one place."),
            (8, 12, "Running, needs you,\nor ready to check."),
            (12, 16, "Scroll through\nwhat came back."),
            (16, 20, "A short report\non each card."),
            (20, 24, "Click to open\nthe conversation."),
            (24, 28, "Star it to keep\nit at the top."),
            (28, 32, "Checked it?\nMark it Dealt with."),
            (32, 36, "Off your list—until\nyour next request."),
            (36, 40, "Expand to see\nall your projects."),
            (40, 46, "Separate conversations,\ngrouped by project."),
            (46, 52, "Keep the goal\nin a project note.")
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
        var cursor = CGPoint(x: 150, y: 37)
        let keyframes: [(Double, CGPoint)] = [
            (0, CGPoint(x: 150, y: 37)), (3.7, CGPoint(x: 150, y: 37)),
            (4.5, CGPoint(x: 30, y: 241)), (7.7, CGPoint(x: 30, y: 241)),
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
                window.setContentSize(CGSize(width: width, height: width * 680 / 390))
            } else if t >= 12 && t < 24 {
                let down = smooth((t - 12) / 3)
                let up = smooth((t - 18) / 3)
                let travel = min(390, max(0, (focusScroll.documentView?.bounds.height ?? 0) - focusScroll.contentView.bounds.height))
                focusScroll.contentView.scroll(to: CGPoint(x: 0, y: travel * (down - up)))
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
            let cue = captions.first { t >= $0.0 && t < $0.1 }!
            // Notes sit beside the pointer rather than in a separate subtitle strip.
            // Keep a gap around the pointed control; clamp the bubble inside phone-safe margins.
            let textStyle = NSMutableParagraphStyle(); textStyle.alignment = .left; textStyle.lineSpacing = 7
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 40, weight: .medium),
                .foregroundColor: NSColor.white, .paragraphStyle: textStyle]
            let boxWidth: CGFloat = 570
            let textHeight = (cue.2 as NSString).boundingRect(with: NSSize(width: boxWidth - 48, height: 300),
                options: .usesLineFragmentOrigin, attributes: attributes).height
            let boxHeight = ceil(textHeight) + 44
            let pointer = CGPoint(x: cursor.x * scale, y: cursor.y * scale)
            let centered = (8..<12).contains(t) || (20..<24).contains(t) || (40..<46).contains(t)
            let right = t < 8 || t >= 46
            let desiredX = centered ? pointer.x - boxWidth / 2 : right ? pointer.x + 44 : pointer.x - boxWidth - 44
            let boxX = min(1080 - boxWidth - 24, max(24, desiredX))
            let boxTop = min(1840 - boxHeight, pointer.y + 48)
            let box = NSRect(x: boxX, y: 1920 - boxTop - boxHeight, width: boxWidth, height: boxHeight)
            let opacity = min(smooth((t - cue.0) / 0.18), smooth((cue.1 - 0.12 - t) / 0.25))
            context.saveGState(); context.setAlpha(opacity)
            let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
            shadow.shadowBlurRadius = 18; shadow.shadowOffset = NSSize(width: 0, height: -5); shadow.set()
            let bubble = NSBezierPath(roundedRect: box, xRadius: 18, yRadius: 18)
            NSColor(calibratedWhite: 0.12, alpha: 0.97).setFill(); bubble.fill()
            NSShadow().set()
            NSColor(calibratedRed: 0.95, green: 0.81, blue: 0.30, alpha: 0.85).setStroke()
            bubble.lineWidth = 2; bubble.stroke()
            (cue.2 as NSString).draw(in: box.insetBy(dx: 24, dy: 22), withAttributes: attributes)
            context.restoreGState()
            let footer = NSMutableParagraphStyle(); footer.alignment = .center
            ("Fictional sessions · desktop workflow" as NSString).draw(in: NSRect(x: 30, y: 5, width: 1020, height: 28), withAttributes: [
                .font: NSFont.systemFont(ofSize: 20), .foregroundColor: NSColor(white: 0.55, alpha: 1), .paragraphStyle: footer])
            NSGraphicsContext.restoreGraphicsState()
            if [1*fps, 5*fps, 10*fps, 15*fps, 22*fps, 25*fps, 27*fps, 30*fps, 34*fps, 37*fps, 40*fps, 49*fps].contains(frame) {
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
