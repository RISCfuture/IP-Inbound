import LocationFormatter
import SwiftUI

struct UTMEntryView: View {
    @State private var value = ""
    let onAccept: (Coordinate) -> Void
    let onCancel: () -> Void

    private let formatter = LocationCoordinateFormatter(format: .utm)

    var body: some View {
        HStack {
            TextField("UTM", text: $value)
                .multilineTextAlignment(.leading)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.accentColor, lineWidth: 2)
                )

            Button(action: { onCancel() }, label: {
                Image(systemName: "xmark")
                    .imageScale(.large)
                    .accessibilityLabel("Cancel")
            })
            Button(action: { onAccept(coordinate!) }, label: {
                Image(systemName: "checkmark")
                    .imageScale(.large)
                    .accessibilityLabel("Accept")
            }).disabled(coordinate == nil)
        }
    }

    private var coordinate: Coordinate? {
        guard let coordinate = try? formatter.coordinate(from: value) else { return nil }
        return .init(coordinate)
    }

    init(coordinate: Coordinate, onAccept: @escaping (Coordinate) -> Void, onCancel: @escaping () -> Void) {
        value = formatter.string(from: coordinate.toCoreLocation) ?? ""
        self.onAccept = onAccept
        self.onCancel = onCancel
    }
}

#Preview {
    @Previewable @State var coordinate = Coordinate(latitude: 37, longitude: -121.5)

    UTMEntryView(coordinate: coordinate, onAccept: { coordinate = $0 }, onCancel: { })
}
