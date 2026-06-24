import SwiftUI

/// A custom keypad for entering MGRS column, row, and band letters.
struct MGRSLetterKeypadView: View {
  private static let letters: [[Character]] = [
    ["A", "B", "C", "D", "E"],
    ["F", "G", "H", "J", "K"],
    ["L", "M", "N", "P", "Q"],
    ["R", "S", "T", "U", "V"],
    ["W", "X", "Y", "Z"]
  ]

  let activeLetters: [Character]
  var isAcceptEnabled = true
  let onKeyPress: (Character) -> Void
  let onBackspace: () -> Void
  let onAccept: () -> Void
  let onCancel: () -> Void

  private var rows: [[KeypadCell]] {
    Self.letters.enumerated().map { index, row in
      var cells = row.map(letterCell)
      if index == Self.letters.count - 1 {
        cells.append(.backspace(action: onBackspace))
      }
      return cells
    }
  }

  var body: some View {
    KeypadGrid(
      columns: 5,
      rows: rows,
      isAcceptEnabled: isAcceptEnabled,
      onAccept: onAccept,
      onCancel: onCancel
    )
  }

  private func letterCell(_ letter: Character) -> KeypadCell {
    .key(
      label: String(letter),
      accessibilityLabel: nil,
      isActive: activeLetters.contains(letter),
      action: { onKeyPress(letter) }
    )
  }
}

#Preview {
  MGRSLetterKeypadView(
    activeLetters: ["A", "B", "C", "L", "M"],
    onKeyPress: { _ in },
    onBackspace: {},
    onAccept: {},
    onCancel: {}
  )
  .padding()
}
