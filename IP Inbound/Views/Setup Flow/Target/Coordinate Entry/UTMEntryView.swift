import SwiftUI

struct UTMEntryView: View {
  let onAccept: (Coordinate) -> Void
  let onCancel: () -> Void

  @State private var entryManager: UTMEntryManager

  var body: some View {
    GeometryReader { geometry in
      let baseline = geometry.size.height / 8

      VStack(spacing: 0) {
        // Display formatted UTM string with cursor
        HStack {
          GeometryReader { geo in
            Text(entryManager.attributedString)
              .font(.system(size: baseline * 0.6).monospaced())
              .minimumScaleFactor(0.5)
              .lineLimit(1)
              .frame(maxWidth: .infinity, maxHeight: baseline * 1.5)
              .layoutPriority(1)
              .onTapGesture { location in
                let charCount = entryManager.stringValue.count
                let widthPerChar = geo.size.width / CGFloat(charCount)
                let charIndex = Int(location.x / widthPerChar)
                if charCount > charIndex {
                  entryManager.setIndex(charIndex)
                }
              }
              .accessibilityAddTraits(.isButton)
          }
          .frame(idealHeight: baseline * 1.5)
        }
        .padding(.bottom, baseline * 0.5)

        Spacer(minLength: 0)

        // Custom keypad based on current input mode
        switch entryManager.inputMode {
          case .zone:
            NumericKeypadView(
              activeDigits: Array(0...9),
              onKeyPress: { entryManager.add(Character("\($0)")) },
              onBackspace: { entryManager.backspace() }
            )
            .frame(height: baseline * 5)
          case .band:
            UTMBandKeypadView(
              activeBands: entryManager.validBands,
              onKeyPress: { entryManager.add($0) },
              onBackspace: { entryManager.backspace() }
            )
            .frame(height: baseline * 5)
          case .numeric:
            NumericKeypadView(
              activeDigits: Array(0...9),
              onKeyPress: { entryManager.add(Character("\($0)")) },
              onBackspace: { entryManager.backspace() }
            )
            .frame(height: baseline * 5)
        }

        // Accept/Cancel buttons
        HStack {
          Spacer()
          Button(
            action: { onCancel() },
            label: {
              Image(systemName: "xmark")
                .resizable()
                .scaledToFit()
                .frame(height: baseline * 0.6)
                .accessibilityLabel("Cancel")
            }
          )
          .frame(height: baseline)
          Spacer()
          Button(
            action: {
              if let coord = entryManager.getCoordinate() {
                onAccept(coord)
              }
            },
            label: {
              Image(systemName: "checkmark")
                .resizable()
                .scaledToFit()
                .frame(height: baseline * 0.6)
                .accessibilityLabel("Accept")
            }
          )
          .frame(height: baseline)
          .disabled(!entryManager.isValid)
          Spacer()
        }
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
}

// Custom keypad for UTM band letters
struct UTMBandKeypadView: View {
  let activeBands: [Character]
  let onKeyPress: (Character) -> Void
  let onBackspace: () -> Void

  private let bands: [[Character?]] = [
    ["C", "D", "E", "F"],
    ["G", "H", "J", "K"],
    ["L", "M", "N", "P"],
    ["Q", "R", "S", "T"],
    ["U", "V", "W", "X"],
    [nil, nil, nil, nil]  // Backspace row
  ]

  var body: some View {
    GeometryReader { geometry in
      let buttonSize = min(geometry.size.width / 4.5, geometry.size.height / 6.5)
      let spacing = buttonSize * 0.15

      VStack(spacing: spacing) {
        ForEach(0..<bands.count, id: \.self) { row in
          HStack(spacing: spacing) {
            if row == bands.count - 1 {
              // Backspace row
              Spacer()
              KeypadButton(
                systemImage: "delete.left",
                accessibilityLabel: "Delete",
                isBackspace: true,
                action: onBackspace
              )
              .frame(width: buttonSize * 2, height: buttonSize)
              Spacer()
            } else {
              ForEach(0..<bands[row].count, id: \.self) { col in
                if let band = bands[row][col] {
                  KeypadButton(
                    label: String(band),
                    isActive: activeBands.contains(band),
                    action: { onKeyPress(band) }
                  )
                  .frame(width: buttonSize, height: buttonSize)
                } else {
                  Color.clear
                    .frame(width: buttonSize, height: buttonSize)
                }
              }
            }
          }
        }
      }
    }
  }
}

#Preview {
  @Previewable @State var coordinate = Coordinate(latitude: 37, longitude: -121.5)

  UTMEntryView(coordinate: coordinate, onAccept: { coordinate = $0 }, onCancel: {})
    .padding()
}
