import SwiftUI
import ShadcnUI

/// ShadKit's card palette, spacing and border, without a shadow on its text.
struct FlatCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.shadcnPalette) private var palette
    @Environment(\.shadcnTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: Space.x6, content: content)
            .padding(.vertical, Space.x6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.card, in: RoundedRectangle(cornerRadius: theme.radius.xl))
            .shadcnBorder(palette.border, cornerRadius: theme.radius.xl)
            .foregroundStyle(palette.cardForeground)
    }
}

struct ControlPanel<Content: View>: View {
    var fillsHeight = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        FlatCard {
            VStack(alignment: .leading, spacing: Space.x4, content: content)
                .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
                .padding(.horizontal, Space.x6)
        }
    }
}

/// Measures both cards at their actual column width, then gives them one height.
struct EqualHeightColumns: Layout {
    var spacing: CGFloat = 16
    var minimumColumnWidth: CGFloat = 250
    var allowedColumnCounts: [Int]? = nil

    private func columns(width: CGFloat, count: Int) -> Int {
        let capacity = max(1, min(count, Int((width + spacing) / (minimumColumnWidth + spacing))))
        return allowedColumnCounts?.filter { $0 > 0 && $0 <= capacity }.max() ?? capacity
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = proposal.width ?? minimumColumnWidth * CGFloat(subviews.count) + spacing * CGFloat(subviews.count - 1)
        let count = columns(width: width, count: subviews.count)
        let cellWidth = max(0, (width - spacing * CGFloat(count - 1)) / CGFloat(count))
        let height = subviews.map { $0.sizeThatFits(ProposedViewSize(width: cellWidth, height: nil)).height }.max() ?? 0
        let rows = Int(ceil(Double(subviews.count) / Double(count)))
        return CGSize(width: width, height: height * CGFloat(rows) + spacing * CGFloat(rows - 1))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        guard !subviews.isEmpty else { return }
        let count = columns(width: bounds.width, count: subviews.count)
        let rows = Int(ceil(Double(subviews.count) / Double(count)))
        let width = max(0, (bounds.width - spacing * CGFloat(count - 1)) / CGFloat(count))
        let height = max(0, (bounds.height - spacing * CGFloat(rows - 1)) / CGFloat(rows))
        for index in subviews.indices {
            subviews[index].place(at: CGPoint(x: bounds.minX + CGFloat(index % count) * (width + spacing),
                                             y: bounds.minY + CGFloat(index / count) * (height + spacing)),
                                  anchor: .topLeading, proposal: ProposedViewSize(width: width, height: height))
        }
    }
}
