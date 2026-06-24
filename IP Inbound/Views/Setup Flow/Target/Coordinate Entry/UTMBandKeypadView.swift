import SwiftUI

/// A custom keypad for entering UTM band letters.
struct UTMBandKeypadView: View {
  private static let bands: [[Character]] = [
    ["C", "D", "E", "F"],
    ["G", "H", "J", "K"],
    ["L", "M", "N", "P"],
    ["Q", "R", "S", "T"],
    ["U", "V", "W", "X"]
  ]

  let activeBands: [Character]
  var isAcceptEnabled = true
  let onKeyPress: (Character) -> Void
  let onBackspace: () -> Void
  let onAccept: () -> Void
  let onCancel: () -> Void

  private var rows: [[KeypadCell]] {
    Self.bands.map { row in row.map(bandCell) }
      + [[.empty, .empty, .empty, .backspace(action: onBackspace)]]
  }

  var body: some View {
    KeypadGrid(
      columns: 4,
      rows: rows,
      isAcceptEnabled: isAcceptEnabled,
      onAccept: onAccept,
      onCancel: onCancel
    )
  }

  private func bandCell(_ band: Character) -> KeypadCell {
    .key(
      label: String(band),
      accessibilityLabel: nil,
      isActive: activeBands.contains(band),
      action: { onKeyPress(band) }
    )
  }
}

#Preview {
  UTMBandKeypadView(
    activeBands: ["C", "D", "S", "T"],
    onKeyPress: { _ in },
    onBackspace: {},
    onAccept: {},
    onCancel: {}
  )
  .padding()
}
