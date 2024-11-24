import SwiftUI

struct DirectionKeypadView: View {
    let activeDirections: [Character]
    let onKeyPress: (Character) -> Void
    let onBackspace: () -> Void

    var body: some View {
        GeometryReader { geometry in
            // Calculate square size
            let cellSize = min(geometry.size.width / 3, geometry.size.height / 3)

            Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    GridButtonSpace(cellSize: cellSize)
                    GridButton(label: {
                        Text("N")
                            .accessibilityLabel("North")
                    }, cellSize: cellSize, onPress: { onKeyPress("N") })
                    .disabled(!activeDirections.contains("N"))
                    GridButtonSpace(cellSize: cellSize)
                }
                GridRow {
                    GridButton(label: {
                        Text("W")
                            .accessibilityLabel("West")
                    }, cellSize: cellSize, onPress: { onKeyPress("W") })
                    .disabled(!activeDirections.contains("W"))
                    GridButtonSpace(cellSize: cellSize)
                    GridButton(label: {
                        Text("E")
                            .accessibilityLabel("East")
                    }, cellSize: cellSize, onPress: { onKeyPress("E") })
                    .disabled(!activeDirections.contains("E"))
                }
                GridRow {
                    GridButtonSpace(cellSize: cellSize)
                    GridButton(label: {
                        Text("S")
                            .accessibilityLabel("South")
                    }, cellSize: cellSize, onPress: { onKeyPress("S") })
                    .disabled(!activeDirections.contains("S"))
                    GridButton(label: {
                        Image(systemName: "delete.backward")
                            .accessibilityLabel("Backspace")
                    }, cellSize: cellSize, onPress: { onBackspace() })
                }
            }
            .frame(width: cellSize * 3, height: cellSize * 3)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}

#Preview {
    DirectionKeypadView(activeDirections: ["N", "S"], onKeyPress: { _ in }, onBackspace: { })
}
