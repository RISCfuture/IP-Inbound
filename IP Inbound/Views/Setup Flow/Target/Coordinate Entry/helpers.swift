import SwiftUI

@ViewBuilder
func GridButtonSpace(cellSize: CGFloat) -> some View {
    Color.clear.frame(width: cellSize, height: cellSize)
}

@ViewBuilder
func GridButton(label: () -> some View, cellSize: CGFloat, isDisabled: Bool = false, onPress: @escaping () -> Void) -> some View {
    Button(action: onPress) {
        label()
            .font(.system(size: cellSize * 0.5))
            .minimumScaleFactor(0.1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
    }.disabled(isDisabled)
    }
