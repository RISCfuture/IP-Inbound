import SwiftUI

/// A custom keypad for entering UTM band letters.
struct UTMBandKeypadView: View {
  private static let columnsPerRow: CGFloat = 4.5
  private static let rowsHigh: CGFloat = 6.5
  private static let spacingFraction: CGFloat = 0.15
  private static let backspaceWidthMultiple: CGFloat = 2

  private static let bands: [[Character?]] = [
    ["C", "D", "E", "F"],
    ["G", "H", "J", "K"],
    ["L", "M", "N", "P"],
    ["Q", "R", "S", "T"],
    ["U", "V", "W", "X"],
    [nil, nil, nil, nil]  // Backspace row.
  ]

  let activeBands: [Character]
  let onKeyPress: (Character) -> Void
  let onBackspace: () -> Void

  var body: some View {
    GeometryReader { geometry in
      let buttonSize = max(
        KeypadButton.minTouchTarget,
        min(
          geometry.size.width / Self.columnsPerRow,
          geometry.size.height / Self.rowsHigh
        )
      )
      let spacing = buttonSize * Self.spacingFraction

      VStack(spacing: spacing) {
        ForEach(0..<Self.bands.count, id: \.self) { row in
          HStack(spacing: spacing) {
            if row == Self.bands.count - 1 {
              Spacer()
              KeypadButton(
                systemImage: "delete.left",
                accessibilityLabel: String(localized: "Delete"),
                isBackspace: true,
                action: onBackspace
              )
              .frame(width: buttonSize * Self.backspaceWidthMultiple, height: buttonSize)
              Spacer()
            } else {
              ForEach(0..<Self.bands[row].count, id: \.self) { col in
                if let band = Self.bands[row][col] {
                  KeypadButton(
                    label: String(band),
                    isActive: activeBands.contains(band),
                    action: { onKeyPress(band) }
                  )
                  .frame(width: buttonSize, height: buttonSize)
                } else {
                  Color.clear
                    .frame(width: buttonSize, height: buttonSize)
                }
              }
            }
          }
        }
      }
    }
  }
}

#Preview {
  UTMBandKeypadView(
    activeBands: ["C", "D", "S", "T"],
    onKeyPress: { _ in },
    onBackspace: {}
  )
  .padding()
}
