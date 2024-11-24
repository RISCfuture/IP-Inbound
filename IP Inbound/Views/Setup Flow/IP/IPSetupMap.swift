import MapKit
import SwiftUI

struct IPSetupMap: View {
    @Bindable var target: Target

    var body: some View {
        Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
            Annotation(target.name, coordinate: target.coordinate.toCoreLocation) {
                Image(systemName: "triangle.fill").foregroundStyle(.red)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            }
            Annotation("IP", coordinate: target.IPCoordinate.toCoreLocation) {
                Image(systemName: "square.fill").foregroundStyle(.yellow)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            }
            MapPolyline(coordinates: [target.coordinate, target.IPCoordinate].map(\.toCoreLocation))
                .stroke(.gray.opacity(0.75), lineWidth: 5)
        }
        .padding()
        .mapStyle(.imagery)
        .mapControls {
            MapScaleView()
            MapUserLocationButton()
        }
    }
}

#Preview {
    let helper = PreviewHelper()
    IPSetupMap(target: helper.target())
        .modelContainer(helper.modelContainer)
}
