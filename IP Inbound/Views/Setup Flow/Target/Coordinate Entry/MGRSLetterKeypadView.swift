import SwiftUI

/// A custom keypad for entering MGRS column, row, and band letters.
struct MGRSLetterKeypadView: View {
  private static let columnsPerRow: CGFloat = 5.5
  private static let rowsHigh: CGFloat = 6.5
  private static let spacingFraction: CGFloat = 0.15
  private static let backspaceWidthMultiple: CGFloat = 2

  private static let letters: [[Character?]] = [
    ["A", "B", "C", "D", "E"],
    ["F", "G", "H", "J", "K"],
    ["L", "M", "N", "P", "Q"],
    ["R", "S", "T", "U", "V"],
    ["W", "X", "Y", "Z", nil],
    [nil, nil, nil, nil, nil]  // Backspace row.
  ]

  let activeLetters: [Character]
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
        ForEach(0..<Self.letters.count, id: \.self) { row in
          HStack(spacing: spacing) {
            if row == Self.letters.count - 1 {
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
              ForEach(0..<Self.letters[row].count, id: \.self) { col in
                if let letter = Self.letters[row][col] {
                  KeypadButton(
                    label: String(letter),
                    isActive: activeLetters.contains(letter),
                    action: { onKeyPress(letter) }
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
  MGRSLetterKeypadView(
    activeLetters: ["A", "B", "C", "L", "M"],
    onKeyPress: { _ in },
    onBackspace: {}
  )
  .padding()
}
