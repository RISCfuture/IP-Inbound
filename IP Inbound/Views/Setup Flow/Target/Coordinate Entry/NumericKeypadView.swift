import SwiftUI

struct NumericKeypadView: View {
  var activeDigits = (0...9).map(\.self)
  var isAcceptEnabled = true
  let onKeyPress: (Character) -> Void
  let onBackspace: () -> Void
  var onAccept: (() -> Void)?
  var onCancel: (() -> Void)?

  private var rows: [[KeypadCell]] {
    [
      digitRow(1...3),
      digitRow(4...6),
      digitRow(7...9),
      [.empty, digitCell(0), .backspace(action: onBackspace)]
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

  private func digitRow(_ digits: ClosedRange<Int>) -> [KeypadCell] {
    digits.map(digitCell)
  }

  private func digitCell(_ digit: Int) -> KeypadCell {
    .key(
      label: String(digit),
      accessibilityLabel: nil,
      isActive: activeDigits.contains(digit),
      action: { onKeyPress(Character("\(digit)")) }
    )
  }
}

#Preview("All digits") {
  NumericKeypadView(onKeyPress: { _ in }, onBackspace: {}, onAccept: {}, onCancel: {})
    .padding()
}

#Preview("Restricted digits") {
  NumericKeypadView(
    activeDigits: [0, 1, 2, 3],
    onKeyPress: { _ in },
    onBackspace: {},
    onAccept: {},
    onCancel: {}
  )
  .padding()
}
