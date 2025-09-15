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
            Picker("Coordinate format", selection: $coordinateFormat) {
                Text("DD").tag(CoordinateFormat.decimalDegrees)
                Text("DDM").tag(CoordinateFormat.degreesDecimalMinutes)
                Text("DMS").tag(CoordinateFormat.degreesMinutesSeconds)
                Text("UTM").tag(CoordinateFormat.utm)
                Text("MGRS").tag(CoordinateFormat.mgrs)
            }.pickerStyle(.segmented)
                .padding(.bottom)

            if coordinateFormat == .utm {
                Spacer()
                UTMEntryView(coordinate: coordinate, onAccept: { onAccept($0) }, onCancel: onCancel)
                Spacer()
            } else if coordinateFormat == .mgrs {
                Spacer()
                MGRSEntryView(coordinate: coordinate, onAccept: { onAccept($0) }, onCancel: onCancel)
                Spacer()
            } else {
                LatLonEntryView(coordinate: coordinate, onAccept: { onAccept($0) }, onCancel: onCancel)
            }
        }
    }

    init(coordinate: Coordinate,
         onAccept: @escaping (Coordinate) -> Void,
         onCancel: @escaping () -> Void) {
        self.coordinate = coordinate
        self.onAccept = onAccept
        self.onCancel = onCancel
    }

    private static func value(from coordinate: Coordinate, format: CoordinateFormat) -> String {
        let style = CoordinateFormatStyle(format: format)
        return coordinate.formatted(style)
    }

    private static func coordinate(from value: String, format: CoordinateFormat) -> Coordinate {
        do {
            return try Coordinate(value, format: format)
        } catch {
            return .init(latitude: 0, longitude: 0)
        }
    }
}

#Preview {
    @Previewable @State var coordinate = Coordinate(
        latitude: 37.123,
        longitude: -121.345
    )

    Group {
        CoordinateEntryView(coordinate: coordinate, onAccept: { coordinate = $0 }, onCancel: { })
    }.padding()
}
