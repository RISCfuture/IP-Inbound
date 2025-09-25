import Defaults
import SwiftUI

struct TOTEntryView: View {
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
      let baseline = geometry.size.height / 10

      VStack(spacing: 0) {
        Picker("Time Display Mode", selection: $entryManager.displayMode) {
          Text("Target Local").tag(DisplayMode.local)
          Text("Zulu").tag(DisplayMode.zulu)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("timeDisplayModePicker")
        .padding(.horizontal)
        .padding(.bottom)

        // Main time display
        HStack {
          Spacer()
          let strings = entryManager.attributedStrings
          if !strings.isEmpty {
            Text(strings[0])
              .font(.system(size: baseline * 0.8).monospaced())
              .minimumScaleFactor(0.5)
              .lineLimit(1)
              .onTapGesture { location in
                let line = strings[0]
                let charCount = line.characters.count
                let widthPerChar = UIScreen.main.bounds.width / CGFloat(charCount + 2)
                let charIndex = Int(location.x / widthPerChar)
                if charIndex < charCount {
                  entryManager.setIndex(lineIndex: 0, charIndex: charIndex)
                }
              }
              .accessibilityAddTraits(.isButton)
              .accessibilityIdentifier("timeEntryField")
          }
          Spacer()
        }
        .padding(.bottom, baseline * 0.3)

        // Secondary info
        VStack(spacing: 4) {
          Text(entryManager.secondaryTimeString)
            .font(.headline)
            .foregroundStyle(.secondary)

          Text(entryManager.relativeTimeString)
            .font(.headline)
            .foregroundStyle(.secondary)
        }
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
        .frame(height: baseline * 5)
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
    onAccept: @escaping (Date) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.onAccept = onAccept
    self.onCancel = onCancel
    self.targetCoordinate = targetCoordinate
    _entryManager = State(
      wrappedValue: .init(
        timeOnTarget: timeOnTarget,
        targetCoordinate: targetCoordinate
      ))
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
