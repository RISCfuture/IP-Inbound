import SwiftUI

struct DirectionKeypadView: View {
  let activeDirections: [Character]
  var isAcceptEnabled = true
  let onKeyPress: (Character) -> Void
  let onBackspace: () -> Void
  let onAccept: () -> Void
  let onCancel: () -> Void

  private var rows: [[KeypadCell]] {
    [
      [.empty, directionCell("N", String(localized: "North")), .empty],
      [
        directionCell("W", String(localized: "West")),
        .empty,
        directionCell("E", String(localized: "East"))
      ],
      [.empty, directionCell("S", String(localized: "South")), .backspace(action: onBackspace)]
    ]
  }

  var body: some View {
    KeypadGrid(
      columns: 3,
      rows: rows,
      isAcceptEnabled: isAcceptEnabled,
      onAccept: onAccept,
      onCancel: onCancel
    )
  }

  private func directionCell(_ direction: Character, _ accessibilityLabel: String) -> KeypadCell {
    .key(
      label: String(direction),
      accessibilityLabel: accessibilityLabel,
      isActive: activeDirections.contains(direction),
      action: { onKeyPress(direction) }
    )
  }
}

#Preview("All directions") {
  DirectionKeypadView(
    activeDirections: ["N", "S", "E", "W"],
    onKeyPress: { _ in },
    onBackspace: {},
    onAccept: {},
    onCancel: {}
  )
  .padding()
}

#Preview("Restricted directions") {
  DirectionKeypadView(
    activeDirections: ["N", "S"],
    onKeyPress: { _ in },
    onBackspace: {},
    onAccept: {},
    onCancel: {}
  )
  .padding()
}
