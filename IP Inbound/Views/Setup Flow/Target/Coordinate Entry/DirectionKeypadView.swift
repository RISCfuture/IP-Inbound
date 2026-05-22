import SwiftUI

struct DirectionKeypadView: View {
  private static let columnsPerRow: CGFloat = 3.5
  private static let rowsHigh: CGFloat = 3.5
  private static let spacingFraction: CGFloat = 0.15

  let activeDirections: [Character]
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
        HStack(spacing: spacing) {
          Color.clear
            .frame(width: buttonSize, height: buttonSize)

          directionButton(
            "N",
            accessibilityLabel: String(localized: "North"),
            buttonSize: buttonSize
          )

          Color.clear
            .frame(width: buttonSize, height: buttonSize)
        }

        HStack(spacing: spacing) {
          directionButton(
            "W",
            accessibilityLabel: String(localized: "West"),
            buttonSize: buttonSize
          )

          Color.clear
            .frame(width: buttonSize, height: buttonSize)

          directionButton(
            "E",
            accessibilityLabel: String(localized: "East"),
            buttonSize: buttonSize
          )
        }

        HStack(spacing: spacing) {
          Color.clear
            .frame(width: buttonSize, height: buttonSize)

          directionButton(
            "S",
            accessibilityLabel: String(localized: "South"),
            buttonSize: buttonSize
          )

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
  private func directionButton(
    _ direction: Character,
    accessibilityLabel: String,
    buttonSize: CGFloat
  ) -> some View {
    KeypadButton(
      label: String(direction),
      isActive: activeDirections.contains(direction),
      action: { onKeyPress(direction) }
    )
    .frame(width: buttonSize, height: buttonSize)
    .accessibilityLabel(accessibilityLabel)
  }
}

#Preview("All directions") {
  DirectionKeypadView(
    activeDirections: ["N", "S", "E", "W"],
    onKeyPress: { _ in },
    onBackspace: {}
  )
  .padding()
}

#Preview("Restricted directions") {
  DirectionKeypadView(activeDirections: ["N", "S"], onKeyPress: { _ in }, onBackspace: {})
    .padding()
}
