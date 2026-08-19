import SwiftUI

/// Lays children out left-to-right, wrapping to a new row when the next child would overflow the
/// available width. Each child keeps its ideal width, so no child is split across rows.
///
/// Children marked with ``SwiftUICore/View/flowSeparator()`` act as separators: a separator is paired
/// with the child that follows it and is shown only when that child stays on the current row. When
/// the following child wraps, the separator is dropped — so a row never begins or ends with one.
struct FlowLayout: Layout {
  private static let offscreenParkingDistance: CGFloat = 10_000

  var spacing: CGFloat = 6
  var rowSpacing: CGFloat = 4

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout Void) -> CGSize {
    let rows = rows(maxWidth: proposal.width ?? .infinity, subviews: subviews)
    let width = rows.map(\.width).max() ?? 0
    let height = rows.map(\.height).reduce(0, +) + rowSpacing * CGFloat(max(0, rows.count - 1))
    return CGSize(width: width, height: height)
  }

  func placeSubviews(
    in bounds: CGRect,
    proposal _: ProposedViewSize,
    subviews: Subviews,
    cache _: inout Void
  ) {
    let rows = rows(maxWidth: bounds.width, subviews: subviews)
    var placed = Set<Int>()
    var y = bounds.minY
    for row in rows {
      // Center the row, but never start left of the bounds: a single element wider than the
      // container would otherwise be clipped on its leading edge.
      var x = bounds.minX + max(0, (bounds.width - row.width) / 2)
      for element in row.elements {
        // Cap the proposed width at the container so an over-wide element truncates within bounds
        // rather than overflowing.
        let width = min(element.size.width, bounds.width)
        subviews[element.index].place(
          at: CGPoint(x: x, y: y + (row.height - element.size.height) / 2),
          anchor: .topLeading,
          proposal: ProposedViewSize(width: width, height: element.size.height)
        )
        placed.insert(element.index)
        x += element.size.width + spacing
      }
      y += row.height + rowSpacing
    }
    // Dropped separators still must be placed; park them well off-screen so they don't render.
    let offscreen = CGPoint(x: bounds.maxX + Self.offscreenParkingDistance, y: bounds.minY)
    for index in subviews.indices where !placed.contains(index) {
      subviews[index].place(at: offscreen, anchor: .topLeading, proposal: .zero)
    }
  }

  private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
    var rows: [Row] = []
    var row = Row()
    var index = 0
    while index < subviews.count {
      if subviews[index][SeparatorTrait.self] {
        // A separator only renders between two content items on the same row. Drop it when it has
        // no following content item — trailing, or before another separator — so a row never
        // begins or ends with one. placeSubviews parks dropped separators off-screen.
        let nextIsContent = index + 1 < subviews.count && !subviews[index + 1][SeparatorTrait.self]
        guard nextIsContent else {
          index += 1
          continue
        }
        let separator = Element(index: index, subview: subviews[index])
        let content = Element(index: index + 1, subview: subviews[index + 1])
        let addedWidth = separator.size.width + content.size.width + 2 * spacing
        if !row.isEmpty, row.width + addedWidth > maxWidth {
          rows.append(row)
          row = Row()
          row.append(content, spacing: spacing)  // drop the separator at the row start
        } else {
          row.append(separator, spacing: spacing)
          row.append(content, spacing: spacing)
        }
        index += 2
      } else {
        let element = Element(index: index, subview: subviews[index])
        if !row.isEmpty, row.width + element.size.width + spacing > maxWidth {
          rows.append(row)
          row = Row()
        }
        row.append(element, spacing: spacing)
        index += 1
      }
    }
    if !row.isEmpty { rows.append(row) }
    return rows
  }

  private struct Element {
    let index: Int
    let size: CGSize

    init(index: Int, subview: LayoutSubview) {
      self.index = index
      size = subview.sizeThatFits(.unspecified)
    }
  }

  private struct Row {
    private(set) var elements: [Element] = []
    private(set) var width: CGFloat = 0
    private(set) var height: CGFloat = 0

    var isEmpty: Bool { elements.isEmpty }

    mutating func append(_ element: Element, spacing: CGFloat) {
      width += (elements.isEmpty ? 0 : spacing) + element.size.width
      height = max(height, element.size.height)
      elements.append(element)
    }
  }
}

private struct SeparatorTrait: LayoutValueKey {
  static let defaultValue = false
}

extension View {
  /// Marks this view as a ``FlowLayout`` separator — shown only between two content items on the
  /// same row, dropped when it would fall at the start of a wrapped row.
  func flowSeparator() -> some View {
    layoutValue(key: SeparatorTrait.self, value: true)
  }
}
