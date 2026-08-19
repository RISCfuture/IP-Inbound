import MeasurementKitLocation
import SwiftUI

struct UTMEntryView: View {
  private static let baselineDivisor: CGFloat = 8
  private static let displaySpacingScale: CGFloat = 0.5
  private static let keypadHeightScale: CGFloat = 6

  let onAccept: (Coordinate) -> Void
  let onCancel: () -> Void

  @State private var entryManager: UTMEntryManager

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
    _entryManager = State(wrappedValue: UTMEntryManager(coordinate: coordinate))
  }

  private func acceptCoordinate() {
    if let coordinate = entryManager.coordinate() {
      onAccept(coordinate)
    }
  }

  @ViewBuilder
  private func keypad(baseline: CGFloat) -> some View {
    let keypadHeight = baseline * Self.keypadHeightScale

    switch entryManager.inputMode {
      case .zone, .numeric:
        NumericKeypadView(
          isAcceptEnabled: entryManager.isValid,
          onKeyPress: { entryManager.add(Character("\($0)")) },
          onBackspace: { entryManager.backspace() },
          onAccept: acceptCoordinate,
          onCancel: onCancel
        )
        .frame(height: keypadHeight)
      case .band:
        UTMBandKeypadView(
          activeBands: entryManager.validBands,
          isAcceptEnabled: entryManager.isValid,
          onKeyPress: { entryManager.add($0) },
          onBackspace: { entryManager.backspace() },
          onAccept: acceptCoordinate,
          onCancel: onCancel
        )
        .frame(height: keypadHeight)
    }
  }
}

#Preview {
  @Previewable @State var coordinate = Coordinate(latitude: 37, longitude: -121.5)

  UTMEntryView(coordinate: coordinate, onAccept: { coordinate = $0 }, onCancel: {})
    .padding()
}
