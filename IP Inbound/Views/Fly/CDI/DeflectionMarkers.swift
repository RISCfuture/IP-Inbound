import SwiftUI

struct DeflectionMarkers: View {
    var scaleWidth: Double // fraction of radius
    var markerCount = 4 // must be even

    private let circleSize: CGFloat = 10

    @State private var markerPositions: [MarkerPosition] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(markerPositions) { position in
                    Circle()
                        .stroke(lineWidth: 2)
                        .frame(width: circleSize, height: circleSize)
                        .position(x: position.x, y: position.y)
                }
            }
            .onAppear {
                calculateMarkerPositions(in: geometry)
            }
            .onChange(of: geometry.size) { _, _ in
                calculateMarkerPositions(in: geometry)
            }
            .onChange(of: scaleWidth) { _, _ in
                calculateMarkerPositions(in: geometry)
            }
        }
    }

    private func calculateMarkerPositions(in geometry: GeometryProxy) {
        let center = geometry.size.center,
            radius = geometry.size.minDimension / 2,
            markerOffset = radius * scaleWidth,
            markerCountPerSide = markerCount / 2

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
