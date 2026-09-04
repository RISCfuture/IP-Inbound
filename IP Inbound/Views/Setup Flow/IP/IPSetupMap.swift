import IP_Inbound_Shared
import MapKit
import MeasurementKitLocation
import SwiftData
import SwiftUI

struct IPSetupMap: View {
  private static let annotationSize = 20.0
  private static let routeLineWidth = 5.0
  private static let routeLineOpacity = 0.75

  @Bindable var target: Target

  var body: some View {
    if ProcessInfo.processInfo.isRunningUITests,
      ProcessInfo.processInfo.environment["UITEST_RENDER_MAPS"] != "1"
    {
      MapPlaceholder()
    } else {
      mapBody
    }
  }

  private var mapBody: some View {
    Map(initialPosition: .automatic, interactionModes: [.pan, .zoom]) {
      Annotation(target.name, coordinate: target.coordinate.clCoordinate) {
        Image(systemName: "triangle.fill").foregroundStyle(.red)
          .frame(width: Self.annotationSize, height: Self.annotationSize)
          .accessibilityHidden(true)
      }
      Annotation("IP", coordinate: target.IPCoordinate.clCoordinate) {
        Image(systemName: "square.fill").foregroundStyle(.yellow)
          .frame(width: Self.annotationSize, height: Self.annotationSize)
          .accessibilityHidden(true)
      }
      MapPolyline(coordinates: [target.coordinate, target.IPCoordinate].map(\.clCoordinate))
        .stroke(.gray.opacity(Self.routeLineOpacity), lineWidth: Self.routeLineWidth)
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
