import SwiftUI

struct MGRSEntryView: View {
  private static let baselineDivisor: CGFloat = 8
  private static let displaySpacingScale: CGFloat = 0.5
  private static let keypadHeightScale: CGFloat = 5

  let onAccept: (Coordinate) -> Void
  let onCancel: () -> Void

  @State private var entryManager: MGRSEntryManager

  var body: some View {
    GeometryReader { geometry in
      let baseline = geometry.size.height / Self.baselineDivisor

      VStack(spacing: 0) {
        CoordinateDisplayLine(
          text: entryManager.attributedString,
          baseline: baseline,
          characterCount: entryManager.stringValue.count,
          onTapCharacter: { entryManager.setIndex($0) }
        )
        .padding(.bottom, baseline * Self.displaySpacingScale)

        Spacer(minLength: 0)

        keypad(baseline: baseline)

        AcceptCancelBar(
          baseline: baseline,
          isAcceptEnabled: entryManager.isValid,
          onAccept: {
            if let coordinate = entryManager.coordinate() {
              onAccept(coordinate)
            }
          },
          onCancel: onCancel
        )
      }
    }
  }

  init(
    coordinate: Coordinate,
    onAccept: @escaping (Coordinate) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.onAccept = onAccept
    self.onCancel = onCancel
    _entryManager = State(wrappedValue: MGRSEntryManager(coordinate: coordinate))
  }

  @ViewBuilder
  private func keypad(baseline: CGFloat) -> some View {
    let keypadHeight = baseline * Self.keypadHeightScale

    switch entryManager.inputMode {
      case .zone, .numeric:
        NumericKeypadView(
          onKeyPress: { entryManager.add(Character("\($0)")) },
          onBackspace: { entryManager.backspace() }
        )
        .frame(height: keypadHeight)
      case .band:
        MGRSLetterKeypadView(
          activeLetters: entryManager.validBands,
          onKeyPress: { entryManager.add($0) },
          onBackspace: { entryManager.backspace() }
        )
        .frame(height: keypadHeight)
      case .column:
        MGRSLetterKeypadView(
          activeLetters: entryManager.validColumns,
          onKeyPress: { entryManager.add($0) },
          onBackspace: { entryManager.backspace() }
        )
        .frame(height: keypadHeight)
      case .row:
        MGRSLetterKeypadView(
          activeLetters: entryManager.validRows,
          onKeyPress: { entryManager.add($0) },
          onBackspace: { entryManager.backspace() }
        )
        .frame(height: keypadHeight)
    }
  }
}

#Preview {
  @Previewable @State var coordinate = Coordinate(latitude: 37, longitude: -121.5)

  MGRSEntryView(coordinate: coordinate, onAccept: { coordinate = $0 }, onCancel: {})
    .padding()
}
