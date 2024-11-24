import Defaults
import LocationFormatter
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
            }.pickerStyle(.segmented)
                .padding(.bottom)

            if coordinateFormat == .utm {
                Spacer()
                UTMEntryView(coordinate: coordinate, onAccept: { onAccept($0) }, onCancel: onCancel)
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
        let formatter = formatter(for: format)
        guard let formatted = formatter.string(from: coordinate.toCoreLocation) else {
            return .init(formatter.string(from: .init())!)
        }
        return formatted
    }

    private static func coordinate(from value: String, format: CoordinateFormat) -> Coordinate {
        let formatter = formatter(for: format)
        guard let coordinate = try? formatter.coordinate(from: value) else {
            return .init(latitude: 0, longitude: 0)
        }
        return .init(coordinate)
    }

    private static func formatter(for format: CoordinateFormat) -> LocationCoordinateFormatter {
        let formatter = LocationCoordinateFormatter()
        formatter.displayOptions = [.compact]
        formatter.symbolStyle = .traditional
        formatter.format = format
        formatter.parsingOptions = .caseInsensitive
        formatter.minimumDegreesFractionDigits = 5
        formatter.maximumDegreesFractionDigits = 5
        return formatter
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
