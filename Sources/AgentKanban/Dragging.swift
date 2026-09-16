import KanbananaCore
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The grip uses ordinary mouse tracking, so quick drops do not wait for an
/// asynchronous system drag session. Title/summary drags still use onDrop.
@MainActor enum CardDragSession {
    static var activeID: String?
    private static var regions: [ObjectIdentifier: WeakRegion] = [:]
    private static weak var highlighted: NativeDropRegion?
    private static var preview: DragPreview?

    static func register(_ region: NativeDropRegion) { regions[ObjectIdentifier(region)] = WeakRegion(region) }
    static func unregister(_ region: NativeDropRegion) { regions.removeValue(forKey: ObjectIdentifier(region)) }
    static func begin(id: String, title: String, color: NSColor, window: NSWindow) {
        cancel()
        activeID = id
        let view = DragPreview(frame: NSRect(x: 0, y: 0, width: 200, height: 44))
        view.title = title; view.color = color
        preview = view
        window.contentView?.addSubview(view)
    }
    private static func destination(at point: NSPoint, in window: NSWindow) -> NativeDropRegion? {
        regions.values.compactMap(\.value).first { region in
            guard region.enabled, region.window === window, !region.isHiddenOrHasHiddenAncestor else { return false }
            // SwiftUI's unclipped native hosts can report a visibleRect larger
            // than the view itself. Both bounds and ancestor clipping matter.
            return region.bounds.intersection(region.visibleRect).contains(region.convert(point, from: nil))
        }
    }
    static func update(at point: NSPoint, in window: NSWindow) {
        guard activeID != nil else { return }
        let target = destination(at: point, in: window)
        if target !== highlighted {
            highlighted?.highlight(false)
            highlighted = target; target?.highlight(true)
        }
        if let preview, let content = window.contentView {
            let local = content.convert(point, from: nil)
            preview.setFrameOrigin(NSPoint(x: local.x + 12, y: local.y - 22))
        }
    }
    static func finish(at point: NSPoint, in window: NSWindow) {
        let id = activeID, target = destination(at: point, in: window)
        cancel()
        if let id, let target { _ = target.action(id) }
    }
    static func cancel() {
        highlighted?.highlight(false); highlighted = nil
        preview?.removeFromSuperview(); preview = nil; activeID = nil
    }
    private final class WeakRegion {
        weak var value: NativeDropRegion?
        init(_ value: NativeDropRegion) { self.value = value }
    }
}

struct CardDragHandle: NSViewRepresentable {
    let id: String
    let title: String
    let color: Color
    var symbol: String?
    func makeNSView(context: Context) -> NativeCardGrip { NativeCardGrip() }
    func updateNSView(_ view: NativeCardGrip, context: Context) {
        view.cardID = id; view.cardTitle = title; view.color = NSColor(color); view.symbol = symbol
        view.toolTip = "Drag \(title) to a column or project"
        view.setAccessibilityLabel("Drag \(title)")
        view.needsDisplay = true
    }
}

final class NativeCardGrip: NSView {
    var cardID = ""
    var cardTitle = ""
    var color = NSColor.secondaryLabelColor
    var symbol: String?
    private var origin: NSPoint?
    private var dragging = false
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true); setAccessibilityRole(.button)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    override func draw(_ dirtyRect: NSRect) {
        if let symbol, let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .semibold))?
            .withSymbolConfiguration(.init(paletteColors: [color])) {
            color.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5).fill()
            let scale = min(14 / image.size.width, 14 / image.size.height)
            let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: NSRect(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width, height: size.height))
            return
        }
        color.withAlphaComponent(0.65).setFill()
        for x in [bounds.midX - 3, bounds.midX + 3] {
            for y in [bounds.midY - 5, bounds.midY, bounds.midY + 5] {
                NSBezierPath(ovalIn: NSRect(x: x - 1, y: y - 1, width: 2, height: 2)).fill()
            }
        }
    }
    override func mouseDown(with event: NSEvent) { origin = event.locationInWindow; dragging = false }
    override func mouseDragged(with event: NSEvent) {
        guard let window, let origin else { return }
        if !dragging {
            guard hypot(event.locationInWindow.x - origin.x, event.locationInWindow.y - origin.y) >= 3 else { return }
            dragging = true
            CardDragSession.begin(id: cardID, title: cardTitle, color: color, window: window)
        }
        CardDragSession.update(at: event.locationInWindow, in: window)
    }
    override func mouseUp(with event: NSEvent) {
        if dragging, let window { CardDragSession.finish(at: event.locationInWindow, in: window) }
        origin = nil; dragging = false
    }
}

private final class DragPreview: NSView {
    var title = ""
    var color = NSColor.labelColor
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.withAlphaComponent(0.95).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()
        color.setFill()
        NSBezierPath(roundedRect: NSRect(x: 7, y: 8, width: 3, height: 28), xRadius: 1, yRadius: 1).fill()
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        (title as NSString).draw(in: NSRect(x: 18, y: 13, width: 172, height: 18), withAttributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.labelColor, .paragraphStyle: paragraph])
    }
}

final class NativeDropRegion: NSView {
    var enabled = false
    var action: (String) -> Bool = { _ in false }
    var highlight: (Bool) -> Void = { _ in }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
private struct CardDropRegion: NSViewRepresentable {
    let enabled: Bool
    let action: (String) -> Bool
    let highlight: (Bool) -> Void
    func makeNSView(context: Context) -> NativeDropRegion {
        let view = NativeDropRegion(); CardDragSession.register(view); return view
    }
    func updateNSView(_ view: NativeDropRegion, context: Context) {
        view.enabled = enabled; view.action = action; view.highlight = highlight
    }
    static func dismantleNSView(_ view: NativeDropRegion, coordinator: ()) { CardDragSession.unregister(view) }
}

private struct CardDropDelegate: DropDelegate {
    @Binding var targeted: Bool
    let enabled: Bool
    let action: (String) -> Bool
    func validateDrop(info: DropInfo) -> Bool { enabled && info.hasItemsConforming(to: [UTType.utf8PlainText]) }
    func dropEntered(info: DropInfo) { targeted = enabled }
    func dropExited(info: DropInfo) { targeted = false }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: enabled ? .move : .cancel) }
    func performDrop(info: DropInfo) -> Bool {
        targeted = false
        guard enabled, let provider = info.itemProviders(for: [UTType.utf8PlainText]).first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { value, _ in
            guard let id = value as? String else { return }
            DispatchQueue.main.async { _ = action(id) }
        }
        return true
    }
}
private struct CardDropTarget: ViewModifier {
    let enabled: Bool
    let action: (String) -> Bool
    @State private var targeted = false
    func body(content: Content) -> some View {
        content
            .background(CardDropRegion(enabled: enabled, action: action, highlight: { targeted = $0 }))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(BoardStyle.ink.opacity(targeted ? 0.45 : 0), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])).allowsHitTesting(false) }
            .onDrop(of: [UTType.utf8PlainText], delegate: CardDropDelegate(targeted: $targeted, enabled: enabled, action: action))
    }
}
extension View {
    func cardDropTarget(enabled: Bool = true, action: @escaping (String) -> Bool) -> some View { modifier(CardDropTarget(enabled: enabled, action: action)) }
}
