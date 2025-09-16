import SwiftUI

struct DirectionKeypadView: View {
  let activeDirections: [Character]
  let onKeyPress: (Character) -> Void
  let onBackspace: () -> Void

  var body: some View {
    GeometryReader { geometry in
      let buttonSize = min(geometry.size.width / 3.5, geometry.size.height / 3.5)
      let spacing = buttonSize * 0.15

      VStack(spacing: spacing) {
        // Row 1: _ N _
        HStack(spacing: spacing) {
          Color.clear
            .frame(width: buttonSize, height: buttonSize)

          KeypadButton(
            label: "N",
            isActive: activeDirections.contains("N"),
            action: { onKeyPress("N") }
          )
          .frame(width: buttonSize, height: buttonSize)
          .accessibilityLabel("North")

          Color.clear
            .frame(width: buttonSize, height: buttonSize)
        }

        // Row 2: W _ E
        HStack(spacing: spacing) {
          KeypadButton(
            label: "W",
            isActive: activeDirections.contains("W"),
            action: { onKeyPress("W") }
          )
          .frame(width: buttonSize, height: buttonSize)
          .accessibilityLabel("West")

          Color.clear
            .frame(width: buttonSize, height: buttonSize)

          KeypadButton(
            label: "E",
            isActive: activeDirections.contains("E"),
            action: { onKeyPress("E") }
          )
          .frame(width: buttonSize, height: buttonSize)
          .accessibilityLabel("East")
        }

        // Row 3: _ S ⌫
        HStack(spacing: spacing) {
          Color.clear
            .frame(width: buttonSize, height: buttonSize)

          KeypadButton(
            label: "S",
            isActive: activeDirections.contains("S"),
            action: { onKeyPress("S") }
          )
          .frame(width: buttonSize, height: buttonSize)
          .accessibilityLabel("South")

          KeypadButton(
            systemImage: "delete.left",
            accessibilityLabel: "Delete",
            isBackspace: true,
            action: onBackspace
          )
          .frame(width: buttonSize, height: buttonSize)
          .accessibilityLabel("Backspace")
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

#Preview {
  DirectionKeypadView(activeDirections: ["N", "S"], onKeyPress: { _ in }, onBackspace: {})
}
