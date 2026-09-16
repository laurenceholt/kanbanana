import SwiftUI

/// Measure every parked card at a fixed column width. Avoid lazy-grid height
/// estimation: changing card content could keep that layout in a transaction
/// loop on macOS, retaining native menu views without returning to the run loop.
struct ParkingGrid: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        geometry(width: proposal.width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = geometry(width: bounds.width, subviews: subviews)
        for (index, frame) in layout.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                                  anchor: .topLeading, proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }

    private func geometry(width: CGFloat?, subviews: Subviews) -> ParkingGridGeometry {
        ParkingGridGeometry(width: width, count: subviews.count) { index, cardWidth in
            subviews[index].sizeThatFits(ProposedViewSize(width: cardWidth, height: nil)).height
        }
    }
}

struct ParkingGridGeometry {
    let size: CGSize
    let frames: [CGRect]

    init(width proposedWidth: CGFloat?, count: Int, measureHeight: (Int, CGFloat) -> CGFloat) {
        let width = proposedWidth.flatMap { $0.isFinite ? max(1, $0) : nil } ?? 230
        let spacing: CGFloat = 10
        let columns = max(1, Int((width + spacing) / (185 + spacing)))
        let cardWidth = min(230, (width - CGFloat(columns - 1) * spacing) / CGFloat(columns))
        var frames: [CGRect] = []
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for index in 0..<max(0, count) {
            let column = index % columns
            if column == 0 && index > 0 { y += rowHeight + spacing; rowHeight = 0 }
            let measured = measureHeight(index, cardWidth)
            let height = measured.isFinite ? max(0, measured) : 0
            frames.append(CGRect(x: CGFloat(column) * (cardWidth + spacing), y: y, width: cardWidth, height: height))
            rowHeight = max(rowHeight, height)
        }
        self.frames = frames
        size = CGSize(width: width, height: frames.isEmpty ? 0 : y + rowHeight)
    }
}
