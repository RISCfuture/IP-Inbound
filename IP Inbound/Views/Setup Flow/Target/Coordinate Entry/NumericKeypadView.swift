import SwiftUI

struct NumericKeypadView: View {
    var activeDigits = (0...9).map(\.self)
    let onKeyPress: (Character) -> Void
    let onBackspace: () -> Void

    var body: some View {
        GeometryReader { geometry in
            // Calculate square size
            let cellSize = min(geometry.size.width / 3, geometry.size.height / 4)

            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    ForEach(1...3, id: \.self) { digit in
                        GridButton(label: { Text(String(digit)) }, cellSize: cellSize, isDisabled: !activeDigits.contains(digit), onPress: {
                            onKeyPress(Character("\(digit)"))
                        })
                    }
                }
                GridRow {
                    ForEach(4...6, id: \.self) { digit in
                        GridButton(label: { Text(String(digit)) }, cellSize: cellSize, isDisabled: !activeDigits.contains(digit), onPress: {
                            onKeyPress(Character("\(digit)"))
                        })
                    }
                }
                GridRow {
                    ForEach(7...9, id: \.self) { digit in
                        GridButton(label: { Text(String(digit)) }, cellSize: cellSize, isDisabled: !activeDigits.contains(digit), onPress: {
                            onKeyPress(Character("\(digit)"))
                        })
                    }
                }
                GridRow {
                    GridButtonSpace(cellSize: cellSize)
                    GridButton(label: { Text("0") }, cellSize: cellSize, isDisabled: !activeDigits.contains(0), onPress: {
                        onKeyPress("0")
                    })
                    GridButton(label: {
                        Image(systemName: "delete.backward")
                            .accessibilityLabel("Backspace")
                    }, cellSize: cellSize, onPress: {
                        onBackspace()
                    })
                }
            }
            .frame(width: cellSize * 3, height: cellSize * 4)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

#Preview {
    NumericKeypadView(onKeyPress: { _ in }, onBackspace: { })
}
