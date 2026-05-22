import SwiftUI

struct NumericKeypadView: View {
  private static let columnsPerRow: CGFloat = 3.5
  private static let rowsHigh: CGFloat = 4.5
  private static let spacingFraction: CGFloat = 0.15

  var activeDigits = (0...9).map(\.self)
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
        digitRow(1...3, buttonSize: buttonSize, spacing: spacing)
        digitRow(4...6, buttonSize: buttonSize, spacing: spacing)
        digitRow(7...9, buttonSize: buttonSize, spacing: spacing)

        HStack(spacing: spacing) {
          Color.clear
            .frame(width: buttonSize, height: buttonSize)

          KeypadButton(
            label: "0",
            isActive: activeDigits.contains(0),
            action: { onKeyPress("0") }
          )
          .frame(width: buttonSize, height: buttonSize)

          KeypadButton(
            systemImage: "delete.left",
            accessibilityLabel: String(localized: "Delete"),
            isBackspace: true,
            action: onBackspace
          )
          .frame(width: buttonSize, height: buttonSize)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  @ViewBuilder
  private func digitRow(
    _ digits: ClosedRange<Int>,
    buttonSize: CGFloat,
    spacing: CGFloat
  ) -> some View {
    HStack(spacing: spacing) {
      ForEach(digits, id: \.self) { digit in
        KeypadButton(
          label: String(digit),
          isActive: activeDigits.contains(digit),
          action: { onKeyPress(Character("\(digit)")) }
        )
        .frame(width: buttonSize, height: buttonSize)
      }
    }
  }
}

#Preview("All digits") {
  NumericKeypadView(onKeyPress: { _ in }, onBackspace: {})
    .padding()
}

#Preview("Restricted digits") {
  NumericKeypadView(activeDigits: [0, 1, 2, 3], onKeyPress: { _ in }, onBackspace: {})
    .padding()
}
