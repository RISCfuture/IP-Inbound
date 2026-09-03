import IP_Inbound_Shared
import MapKit
import MeasurementKitLocation
import SwiftUI

struct TargetSetupMap: View {
  private static let defaultCameraDistanceMeters: Double = 10_000
  private static let targetMarkerSize: CGFloat = 20

  @Bindable var target: Target

  @State private var cameraPosition: MapCameraPosition = .automatic
  @State private var skipUpdate = false
  @State private var currentDistance: Double = Self.defaultCameraDistanceMeters

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
    Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
      Annotation(target.name, coordinate: target.coordinate.clCoordinate) {
        Image(systemName: "triangle.fill").foregroundStyle(.red)
          .frame(width: Self.targetMarkerSize, height: Self.targetMarkerSize)
          .accessibilityHidden(true)
      }
    }
    .padding()
    .mapStyle(.imagery)
    .mapControls {
      MapScaleView()
      MapUserLocationButton()
    }
    .onAppear {
      cameraPosition = .camera(
        .init(
          centerCoordinate: target.coordinate.clCoordinate,
          distance: Self.defaultCameraDistanceMeters
        )
      )
    }
    .onMapCameraChange(frequency: .continuous) { context in
      skipUpdate = true
      currentDistance = context.camera.distance
      target.coordinate = .init(context.camera.centerCoordinate)
    }
    .onMapCameraChange(frequency: .onEnd) {
      target.calculateDeclination()
    }
    .onChange(of: target.coordinate) { _, newValue in
      guard !skipUpdate else {
        skipUpdate = false
        return
      }
      // Center map on new coordinate while preserving zoom level
      cameraPosition = .camera(
        .init(centerCoordinate: newValue.clCoordinate, distance: currentDistance)
      )
    }
  }
}

#Preview {
  let helper = PreviewHelper()
  TargetSetupMap(target: helper.target())
    .modelContainer(helper.modelContainer)
}
