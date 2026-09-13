import SwiftUI

struct GalleryTagListView: View {
    let title: String
    let tags: [GalleryTag]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            GalleryTagFlowView(tags: tags)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GalleryTagFlowView: View {
    let tags: [GalleryTag]

    var body: some View {
        TagFlowLayout(spacing: 8) {
            ForEach(Array(sortedTags.enumerated()), id: \.offset) { _, tag in
                GalleryTagView(tag: tag)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sortedTags: [GalleryTag] {
        tags.sorted { lhs, rhs in
            let lhsPriority = categoryPriority(lhs.category)
            let rhsPriority = categoryPriority(rhs.category)

            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)

            if comparison == .orderedSame {
                return lhs.name < rhs.name
            }

            return comparison == .orderedAscending
        }
    }

    private func categoryPriority(_ category: GalleryTag.Category) -> Int {
        switch category {
        case .male:
            return 0
        case .female:
            return 1
        case .other:
            return 2
        }
    }
}

private struct GalleryTagView: View {
    let tag: GalleryTag

    var body: some View {
        Text(tag.displayName)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.16))
            .clipShape(Capsule())
    }

    private var color: Color {
        switch tag.category {
        case .male:
            return .blue
        case .female:
            return .pink
        case .other:
            return .gray
        }
    }
}

private struct TagFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var measuredWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(
                ProposedViewSize(
                    width: availableWidth.isFinite ? availableWidth : nil,
                    height: nil
                )
            )
            let nextWidth = currentRowWidth == 0
                ? size.width
                : currentRowWidth + spacing + size.width

            if currentRowWidth > 0, nextWidth > availableWidth {
                measuredWidth = max(measuredWidth, currentRowWidth)
                totalHeight += currentRowHeight + spacing
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth = nextWidth
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        measuredWidth = max(measuredWidth, currentRowWidth)
        totalHeight += currentRowHeight

        return CGSize(width: measuredWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(
                ProposedViewSize(width: bounds.width, height: nil)
            )

            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += currentRowHeight + spacing
                currentRowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )

            x += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}
