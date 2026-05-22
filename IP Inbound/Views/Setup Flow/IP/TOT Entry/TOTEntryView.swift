import Defaults
import SwiftUI

struct TOTEntryView: View {
  private static let baselineDivisor = 10.0
  private static let timeDisplayBottomPaddingFactor = 0.3
  private static let keypadHeightFactor = 5.0

  let onAccept: (Date) -> Void
  let onCancel: () -> Void
  let targetCoordinate: Coordinate

  @State private var entryManager: TOTEntryManager

  @Default(.TOTDisplayMode)
  private var displayMode

  private var activeDigits: [Int] {
    (0...9).filter { entryManager.isValidCharacter(Character("\($0)")) }
  }

  var body: some View {
    GeometryReader { geometry in
      let baseline = geometry.size.height / Self.baselineDivisor

      VStack(spacing: 0) {
        Picker("Time Display Mode", selection: $entryManager.displayMode) {
          Text("Target Local").tag(DisplayMode.local)
          Text("Zulu").tag(DisplayMode.zulu)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("timeDisplayModePicker")
        .padding(.horizontal)
        .padding(.bottom)

        TOTTimeDisplayView(entryManager: entryManager, baseline: baseline)
          .padding(.bottom, baseline * Self.timeDisplayBottomPaddingFactor)

        TOTSecondaryInfoView(entryManager: entryManager)
          .padding(.bottom)

        Spacer()

        NumericKeypadView(
          activeDigits: activeDigits,
          onKeyPress: {
            entryManager.add($0)
            onAccept(entryManager.timeOnTarget)
          },
          onBackspace: {
            entryManager.backspace()
            onAccept(entryManager.timeOnTarget)
          }
        )
        .frame(height: baseline * Self.keypadHeightFactor)
        .padding(.horizontal)

        Spacer()
      }
    }
    .onChange(of: entryManager.timeOnTarget) { _, newValue in
      onAccept(newValue)
    }
  }

  init(
    timeOnTarget: Date?,
    targetCoordinate: Coordinate,
    dateProvider: DateProvider = .system,
    onAccept: @escaping (Date) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.onAccept = onAccept
    self.onCancel = onCancel
    self.targetCoordinate = targetCoordinate
    _entryManager = State(
      wrappedValue: .init(
        timeOnTarget: timeOnTarget,
        targetCoordinate: targetCoordinate,
        dateProvider: dateProvider
      )
    )
  }
}

#Preview {
  @Previewable @State var tot = Date().addingTimeInterval(30 * 60)
  let coordinate = Coordinate(latitude: 37.5, longitude: -121.5)

  TOTEntryView(
    timeOnTarget: tot,
    targetCoordinate: coordinate,
    onAccept: { tot = $0 },
    onCancel: {}
  )
  .padding()
}
