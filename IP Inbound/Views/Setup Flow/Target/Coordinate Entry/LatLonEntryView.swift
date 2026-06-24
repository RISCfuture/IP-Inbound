import Defaults
import SwiftUI

struct LatLonEntryView: View {
  private static let baselineDivisor: CGFloat = 8
  private static let keypadHeightScale: CGFloat = 6

  let onAccept: (Coordinate) -> Void
  let onCancel: () -> Void

  @State private var entryManager: CoordinateEntryManager

  @Default(.coordinateFormat)
  private var coordinateFormat

  private var activeDirections: [Character] {
    ["N", "S", "E", "W"].filter { entryManager.isValidCharacter($0) }
  }

  private var activeDigits: [Int] {
    (0...9).filter { entryManager.isValidCharacter(Character("\($0)")) }
  }

  private var isLatLonFormat: Bool {
    coordinateFormat == .decimalDegrees
      || coordinateFormat == .degreesMinutesSeconds
      || coordinateFormat == .degreesDecimalMinutes
  }

  var body: some View {
    if isLatLonFormat {
      GeometryReader { geometry in
        let baseline = geometry.size.height / Self.baselineDivisor

        VStack(spacing: 0) {
          LatLonDisplayLines(
            lines: entryManager.attributedStrings,
            baseline: baseline,
            onTapCharacter: { lineIndex, charIndex in
              entryManager.setIndex(lineIndex: lineIndex, charIndex: charIndex)
            }
          )

          Spacer(minLength: 0)

          keypad(baseline: baseline)
        }
      }
    } else {
      Spacer()
    }
  }

  init(
    coordinate: Coordinate,
    onAccept: @escaping (Coordinate) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.onAccept = onAccept
    self.onCancel = onCancel
    _entryManager = State(wrappedValue: .init(coordinate: coordinate))
  }

  @ViewBuilder
  private func keypad(baseline: CGFloat) -> some View {
    let keypadHeight = baseline * Self.keypadHeightScale

    switch entryManager.digitType {
      case .numeric:
        NumericKeypadView(
          activeDigits: activeDigits,
          onKeyPress: { entryManager.add($0) },
          onBackspace: { entryManager.backspace() },
          onAccept: { onAccept(entryManager.coordinate) },
          onCancel: onCancel
        )
        .frame(height: keypadHeight)
      case .hemisphere:
        DirectionKeypadView(
          activeDirections: activeDirections,
          onKeyPress: { entryManager.add($0) },
          onBackspace: { entryManager.backspace() },
          onAccept: { onAccept(entryManager.coordinate) },
          onCancel: onCancel
        )
        .frame(height: keypadHeight)
      case .open:
        Spacer()
          .frame(height: keypadHeight)
    }
  }
}

#Preview {
  @Previewable @State var coordinate = Coordinate(latitude: 37.5, longitude: -121.5)

  LatLonEntryView(coordinate: coordinate, onAccept: { coordinate = $0 }, onCancel: {})
    .padding()
}
