import AppKit

// Transparent overlay: keep the final Projects view visible beneath the URL.
let size = NSSize(width: 1080, height: 1920)
let image = NSImage(size: size)
image.lockFocus()
NSColor.black.withAlphaComponent(0.72).setFill()
NSRect(origin: .zero, size: size).fill()
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let url = "github.com/laurenceholt/kanbanana" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 51, weight: .semibold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph
]
let bounds = url.boundingRect(with: NSSize(width: 1000, height: 200), options: .usesLineFragmentOrigin, attributes: attributes)
url.draw(in: NSRect(x: 40, y: (1920 - bounds.height) / 2, width: 1000, height: bounds.height), withAttributes: attributes)
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
