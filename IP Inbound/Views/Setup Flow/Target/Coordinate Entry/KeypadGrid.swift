import SwiftUI

/// One slot in a ``KeypadGrid`` row: a labeled key, the shared backspace, or an empty spacer that
/// reserves a column so every keypad lines up on the same grid.
enum KeypadCell {
  case key(label: String, accessibilityLabel: String?, isActive: Bool, action: () -> Void)
  case backspace(action: () -> Void)
  case empty
}

/// The shared layout for every coordinate-entry keypad.
///
/// All keypads place their keys on this one grid — only the cell contents differ between formats —
/// and, when present, the cancel and accept actions occupy a final row, centered and sized to
/// match the keys, with cancel to the left of accept. Keypads with no accept/cancel (such as the
/// live-updating time-on-target pad) simply omit that row.
struct KeypadGrid: View {
  /// Gap between keys as a fraction of a key's size.
  private static let spacingFraction: CGFloat = 0.15
  /// Half a key of breathing room added to each axis so keys don't crowd the keypad's edges.
  private static let edgeMargin: CGFloat = 0.5
  /// Matches the digit keys' glyph size so the check and cross read at the same scale as the
  /// numbers.
  private static let actionGlyphFontSize: CGFloat = 24

  let columns: Int
  let rows: [[KeypadCell]]
  var isAcceptEnabled = true
  var onAccept: (() -> Void)?
  var onCancel: (() -> Void)?

  private var totalRows: Int { rows.count + (hasActionRow ? 1 : 0) }
  private var hasActionRow: Bool { onAccept != nil && onCancel != nil }

  var body: some View {
    GeometryReader { geometry in
      let buttonSize = max(
        KeypadButton.minTouchTarget,
        min(
          geometry.size.width / (CGFloat(columns) + Self.edgeMargin),
          geometry.size.height / (CGFloat(totalRows) + Self.edgeMargin)
        )
      )
      let spacing = buttonSize * Self.spacingFraction

      VStack(spacing: spacing) {
        ForEach(0..<rows.count, id: \.self) { row in
          keyRow(rows[row], buttonSize: buttonSize, spacing: spacing)
        }

        if let onAccept, let onCancel {
          actionRow(
            onAccept: onAccept,
            onCancel: onCancel,
            buttonSize: buttonSize,
            spacing: spacing
          )
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  @ViewBuilder
  private func keyRow(
    _ cells: [KeypadCell],
    buttonSize: CGFloat,
    spacing: CGFloat
  ) -> some View {
    HStack(spacing: spacing) {
      ForEach(0..<cells.count, id: \.self) { column in
        cell(cells[column], buttonSize: buttonSize)
      }
    }
  }

  @ViewBuilder
  private func cell(_ cell: KeypadCell, buttonSize: CGFloat) -> some View {
    switch cell {
      case let .key(label, accessibilityLabel, isActive, action):
        KeypadButton(label: label, isActive: isActive, action: action)
          .frame(width: buttonSize, height: buttonSize)
          .accessibilityLabel(Text(accessibilityLabel ?? label))
      case let .backspace(action):
        KeypadButton(
          systemImage: "delete.left",
          accessibilityLabel: String(localized: "Delete"),
          isBackspace: true,
          action: action
        )
        .frame(width: buttonSize, height: buttonSize)
      case .empty:
        Color.clear
          .frame(width: buttonSize, height: buttonSize)
    }
  }

  @ViewBuilder
  private func actionRow(
    onAccept: @escaping () -> Void,
    onCancel: @escaping () -> Void,
    buttonSize: CGFloat,
    spacing: CGFloat
  ) -> some View {
    HStack(spacing: spacing) {
      actionButton(
        systemImage: "xmark",
        accessibilityLabel: Text("Cancel"),
        buttonSize: buttonSize,
        action: onCancel
      )

      actionButton(
        systemImage: "checkmark",
        accessibilityLabel: Text("Accept"),
        buttonSize: buttonSize,
        action: onAccept
      )
      .disabled(!isAcceptEnabled)
    }
  }

  @ViewBuilder
  private func actionButton(
    systemImage: String,
    accessibilityLabel: Text,
    buttonSize: CGFloat,
    action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: Self.actionGlyphFontSize, weight: .medium))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .accessibilityLabel(accessibilityLabel)
    }
    .buttonStyle(.glassProminent)
    .buttonBorderShape(.circle)
    .frame(width: buttonSize, height: buttonSize)
  }
}

#Preview("3-column (numeric)") {
  KeypadGrid(
    columns: 3,
    rows: [
      [
        .key(label: "1", accessibilityLabel: nil, isActive: true, action: {}),
        .key(label: "2", accessibilityLabel: nil, isActive: true, action: {}),
        .key(label: "3", accessibilityLabel: nil, isActive: true, action: {})
      ],
      [
        .empty, .key(label: "0", accessibilityLabel: nil, isActive: true, action: {}),
        .backspace(action: {})
      ]
    ],
    isAcceptEnabled: true,
    onAccept: {},
    onCancel: {}
  )
  .padding()
}

#Preview("Accept disabled") {
  KeypadGrid(
    columns: 3,
    rows: [[.empty, .empty, .backspace(action: {})]],
    isAcceptEnabled: false,
    onAccept: {},
    onCancel: {}
  )
  .padding()
}
