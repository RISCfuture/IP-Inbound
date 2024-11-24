import Defaults
import LocationFormatter
import SwiftUI

struct LatLonEntryView: View {
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

    var body: some View {
        if coordinateFormat != .decimalDegrees && coordinateFormat != .degreesMinutesSeconds && coordinateFormat != .degreesDecimalMinutes {
            Spacer()
        } else {
            GeometryReader { geometry in
                let baseline = geometry.size.height / 8,
                    strings = entryManager.attributedStrings

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(0..<strings.count, id: \.self) { lineIndex in
                            HStack {
                                GeometryReader { geo in
                                    Text(strings[lineIndex])
                                        .font(.system(size: baseline * 0.8).monospaced())
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, maxHeight: baseline)
                                        .layoutPriority(1)
                                        .onTapGesture { location in
                                            let line = strings[lineIndex],
                                                charCount = line.characters.count,
                                                widthPerChar = geo.size.width / CGFloat(charCount),
                                                charIndex = Int(location.x / widthPerChar)
                                            if charCount > charIndex {
                                                entryManager.setIndex(lineIndex: lineIndex, charIndex: charIndex)
                                            }
                                        }
                                        .accessibilityAddTraits(.isButton)
                                }
                                .frame(idealHeight: baseline)
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    switch entryManager.digitType {
                        case .numeric:
                            NumericKeypadView(activeDigits: activeDigits,
                                              onKeyPress: { entryManager.add($0) },
                                              onBackspace: { entryManager.backspace() })
                            .frame(height: baseline * 5)
                        case .hemisphere:
                            DirectionKeypadView(activeDirections: activeDirections,
                                                onKeyPress: { entryManager.add($0) },
                                                onBackspace: { entryManager.backspace() })
                            .frame(height: baseline * 5)
                        default:
                            Spacer()
                                .frame(height: baseline * 5)
                    }

                    HStack {
                        Spacer()
                        Button(action: { onCancel() }, label: {
                            Image(systemName: "xmark")
                                .resizable()
                                .scaledToFit()
                                .frame(height: baseline * 0.6)
                                .accessibilityLabel("Cancel")
                        })
                        .scaledToFit()
                        .frame(height: baseline)
                        Spacer()
                        Button(action: { onAccept(entryManager.coordinate) }, label: {
                            Image(systemName: "checkmark")
                                .resizable()
                                .scaledToFit()
                                .frame(height: baseline * 0.6)
                                .accessibilityLabel("Accept")
                        })
                        .frame(height: baseline)
                        Spacer()
                    }
                }
            }
        }
    }

    init(coordinate: Coordinate, onAccept: @escaping (Coordinate) -> Void, onCancel: @escaping () -> Void) {
        self.onAccept = onAccept
        self.onCancel = onCancel
        _entryManager = State(wrappedValue: .init(coordinate: coordinate))
    }
}

#Preview {
    @Previewable @State var coordinate = Coordinate(latitude: 37, longitude: -121.5)

    LatLonEntryView(coordinate: coordinate, onAccept: { coordinate = $0 }, onCancel: { })
}
