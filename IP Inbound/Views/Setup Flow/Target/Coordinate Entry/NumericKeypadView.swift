import SwiftUI

struct NumericKeypadView: View {
    var activeDigits = (0...9).map(\.self)
    let onKeyPress: (Character) -> Void
    let onBackspace: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let buttonSize = min(geometry.size.width / 3.5, geometry.size.height / 4.5)
            let spacing = buttonSize * 0.15

            VStack(spacing: spacing) {
                // Row 1: 1 2 3
                HStack(spacing: spacing) {
                    ForEach(1...3, id: \.self) { digit in
                        KeypadButton(
                            label: String(digit),
                            isActive: activeDigits.contains(digit),
                            action: { onKeyPress(Character("\(digit)")) }
                        )
                        .frame(width: buttonSize, height: buttonSize)
                    }
                }

                // Row 2: 4 5 6
                HStack(spacing: spacing) {
                    ForEach(4...6, id: \.self) { digit in
                        KeypadButton(
                            label: String(digit),
                            isActive: activeDigits.contains(digit),
                            action: { onKeyPress(Character("\(digit)")) }
                        )
                        .frame(width: buttonSize, height: buttonSize)
                    }
                }

                // Row 3: 7 8 9
                HStack(spacing: spacing) {
                    ForEach(7...9, id: \.self) { digit in
                        KeypadButton(
                            label: String(digit),
                            isActive: activeDigits.contains(digit),
                            action: { onKeyPress(Character("\(digit)")) }
                        )
                        .frame(width: buttonSize, height: buttonSize)
                    }
                }

                // Row 4: _ 0 ⌫
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
    NumericKeypadView(onKeyPress: { _ in }, onBackspace: { })
}
