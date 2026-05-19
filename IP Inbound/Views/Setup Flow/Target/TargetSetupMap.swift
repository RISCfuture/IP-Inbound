import MapKit
import SwiftUI

struct TargetSetupMap: View {
  @Bindable var target: Target
  @State private var cameraPosition: MapCameraPosition = .automatic
  @State private var skipUpdate = false
  @State private var currentDistance: Double = 10_000

  var body: some View {
    if ProcessInfo.processInfo.isRunningUITests {
      MapPlaceholder()
    } else {
      mapBody
    }
  }

  private var mapBody: some View {
    Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
      Annotation(target.name, coordinate: target.coordinate.toCoreLocation) {
        Image(systemName: "triangle.fill").foregroundStyle(.red)
          .frame(width: 20, height: 20)
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
        .init(centerCoordinate: target.coordinate.toCoreLocation, distance: 10_000)
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
        .init(centerCoordinate: newValue.toCoreLocation, distance: currentDistance)
      )
    }
  }
}

#Preview {
  let helper = PreviewHelper()
  TargetSetupMap(target: helper.target())
    .modelContainer(helper.modelContainer)
}
