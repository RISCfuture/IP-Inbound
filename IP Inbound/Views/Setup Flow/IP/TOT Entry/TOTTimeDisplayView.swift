import MeasurementKitLocation
import SwiftUI

/// The large, tappable monospaced time readout for TOT entry. Tapping a character moves the
/// edit cursor to that digit; hit-testing uses the text's rendered width rather than the screen
/// width so the mapping stays accurate regardless of layout.
struct TOTTimeDisplayView: View {
  private static let fontSizeFactor = 0.8
  private static let minimumScaleFactor = 0.5

  let entryManager: TOTEntryManager
  let baseline: CGFloat

  @State private var renderedWidth: CGFloat = 0

  var body: some View {
    HStack {
      Spacer()
      let strings = entryManager.attributedStrings
      if let firstLine = strings.first {
        Text(firstLine)
          .font(.system(size: baseline * Self.fontSizeFactor).monospaced())
          .minimumScaleFactor(Self.minimumScaleFactor)
          .lineLimit(1)
          .background(widthReader)
          .onTapGesture { location in
            entryManager.selectIndex(atTapX: location.x, lineWidth: renderedWidth)
          }
          .accessibilityAddTraits(.isButton)
          .accessibilityIdentifier("timeEntryField")
      }
      Spacer()
    }
  }

  private var widthReader: some View {
    GeometryReader { geometry in
      Color.clear
        .onAppear { renderedWidth = geometry.size.width }
        .onChange(of: geometry.size.width) { _, newWidth in renderedWidth = newWidth }
    }
  }
}

#Preview {
  let coordinate = Coordinate(latitude: 37.5, longitude: -121.5)
  let manager = TOTEntryManager(
    timeOnTarget: Date().addingTimeInterval(30 * 60),
    targetCoordinate: coordinate
  )

  TOTTimeDisplayView(entryManager: manager, baseline: 60)
    .padding()
}
