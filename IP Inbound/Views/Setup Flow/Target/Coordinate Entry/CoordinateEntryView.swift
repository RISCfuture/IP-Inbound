import Defaults
import SwiftUI

struct CoordinateEntryView: View {
  @State private var coordinate: Coordinate
  var onAccept: (Coordinate) -> Void
  var onCancel: () -> Void

  @Default(.coordinateFormat)
  private var coordinateFormat

  var body: some View {
    VStack(spacing: 0) {
      Picker(String(localized: "Coordinate format"), selection: $coordinateFormat) {
        Text("DD").tag(CoordinateFormat.decimalDegrees)
        Text("DDM").tag(CoordinateFormat.degreesDecimalMinutes)
        Text("DMS").tag(CoordinateFormat.degreesMinutesSeconds)
        Text("UTM").tag(CoordinateFormat.utm)
        Text("MGRS").tag(CoordinateFormat.mgrs)
      }.pickerStyle(.segmented)
        .accessibilityIdentifier("coordinateFormatPicker")
        .padding(.bottom)

      if coordinateFormat == .utm {
        Spacer()
        UTMEntryView(coordinate: coordinate, onAccept: onAccept, onCancel: onCancel)
        Spacer()
      } else if coordinateFormat == .mgrs {
        Spacer()
        MGRSEntryView(coordinate: coordinate, onAccept: onAccept, onCancel: onCancel)
        Spacer()
      } else {
        LatLonEntryView(coordinate: coordinate, onAccept: onAccept, onCancel: onCancel)
      }
    }
  }

  init(
    coordinate: Coordinate,
    onAccept: @escaping (Coordinate) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.coordinate = coordinate
    self.onAccept = onAccept
    self.onCancel = onCancel
  }
}

#Preview("Lat/Lon") {
  @Previewable @State var coordinate = Coordinate(latitude: 37.123, longitude: -121.345)

  CoordinateEntryView(coordinate: coordinate, onAccept: { coordinate = $0 }, onCancel: {})
    .onAppear { Defaults[.coordinateFormat] = .decimalDegrees }
    .padding()
}

#Preview("UTM") {
  @Previewable @State var coordinate = Coordinate(latitude: 37.123, longitude: -121.345)

  CoordinateEntryView(coordinate: coordinate, onAccept: { coordinate = $0 }, onCancel: {})
    .onAppear { Defaults[.coordinateFormat] = .utm }
    .padding()
}

#Preview("MGRS") {
  @Previewable @State var coordinate = Coordinate(latitude: 37.123, longitude: -121.345)

  CoordinateEntryView(coordinate: coordinate, onAccept: { coordinate = $0 }, onCancel: {})
    .onAppear { Defaults[.coordinateFormat] = .mgrs }
    .padding()
}
