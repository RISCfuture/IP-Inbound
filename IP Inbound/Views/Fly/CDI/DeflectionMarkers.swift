import SwiftUI

struct DeflectionMarkers: View {
  /// Full-scale needle travel, as a fraction of the rose's radius. The outermost marker sits at
  /// full deflection.
  var fullScaleRadiusFraction: Double
  var markerCount = 4  // must be even

  private let circleSize: CGFloat = 10,
    circleLineWidth: CGFloat = 2

  @State private var markerPositions: [MarkerPosition] = []

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        ForEach(markerPositions) { position in
          Circle()
            .stroke(lineWidth: circleLineWidth)
            .frame(width: circleSize, height: circleSize)
            .position(x: position.x, y: position.y)
        }
      }
      .accessibilityHidden(true)
      .onAppear {
        calculateMarkerPositions(in: geometry)
      }
      .onChange(of: geometry.size) { _, _ in
        calculateMarkerPositions(in: geometry)
      }
      .onChange(of: fullScaleRadiusFraction) { _, _ in
        calculateMarkerPositions(in: geometry)
      }
    }
  }

  private func calculateMarkerPositions(in geometry: GeometryProxy) {
    let center = geometry.size.center
    let radius = geometry.size.minDimension / 2
    let markerOffset = radius * fullScaleRadiusFraction
    let markerCountPerSide = markerCount / 2

    markerPositions = (-markerCountPerSide...markerCountPerSide).compactMap { marker in
      guard marker != 0 else { return nil }
      let offset = markerOffset * Double(marker) / Double(markerCountPerSide)
      return MarkerPosition(
        id: Double(marker),
        x: center.x + offset,
        y: center.y
      )
    }
  }

  // Cache marker positions to avoid recalculating on every render
  private struct MarkerPosition: Identifiable {
    let id: Double
    let x: CGFloat
    let y: CGFloat
  }
}

#Preview {
  DeflectionMarkers(fullScaleRadiusFraction: 0.75)
    .frame(width: 300, height: 300)
    .padding()
}
