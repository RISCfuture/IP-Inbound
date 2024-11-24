import SwiftUI

struct CDIView: View {
    var heading: Bearing
    var bearing: Bearing?
    var bearingColor = Color.accentColor
    var IPDirectBearing: Bearing?
    var targetDirectBearing: Bearing?
    var crossTrackDistance: Measurement<UnitLength>?
    var distanceScale = Measurement(value: 4, unit: UnitLength.nauticalMiles)

    private let scaleWidth = 0.75 // fraction of radius

    private var deflection: CGFloat? {
        guard let crossTrackDistance else { return nil }

        let deflection = crossTrackDistance / distanceScale
        return min(deflection, 1.0)
    }

    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2,
                center = geo.size.center

            ZStack {
                Text("TRK")
                    .foregroundStyle(.purple)
                    .fontWeight(.bold)

                FixedRotatingView(targetAngle: -heading.degrees) { angle in
                    Group {
                        CompassRose()
                            .stroke(lineWidth: 2)
                        CompassNumbers(rotation: heading.degrees)
                            .drawingGroup()
                    }.rotationEffect(.degrees(angle))
                }

                // IP chevron - only animate when necessary
                if let ipRelative = relative(bearing: IPDirectBearing) {
                    FixedRotatingView(targetAngle: ipRelative) { angle in
                        DirectPointer(label: "IP", color: .yellow)
                            .position(x: center.x, y: center.y - radius * 0.8)
                            .rotationEffect(.degrees(angle), anchor: .center)
                            .animation(.linear, value: ipRelative)
                            .drawingGroup()
                    }
                }

                // target chevron - only animate when necessary
                if let targetRelative = relative(bearing: targetDirectBearing) {
                    FixedRotatingView(targetAngle: targetRelative) { angle in
                        DirectPointer(label: "T", color: .red)
                            .position(x: center.x, y: center.y - radius * 0.8)
                            .rotationEffect(.degrees(angle), anchor: .center)
                            .drawingGroup()
                    }
                }

                // bearing pointer - only animate when necessary
                if let relativeBearing = relative(bearing: bearing) {
                    FixedRotatingView(targetAngle: relativeBearing) { angle in
                        Group {
                            DeflectionMarkers(scaleWidth: scaleWidth)
                                .drawingGroup()
                            BearingLine(deflection: deflection, maxDeflection: scaleWidth)
                                .stroke(lineWidth: 5)
                                .foregroundColor(bearingColor)
                                .drawingGroup()
                        }
                        .rotationEffect(.degrees(angle))
                    }
                }

                // lubber line
                LubberLine()
                    .stroke(.accent, lineWidth: 5)
                    .drawingGroup()
            }
        }
    }

    private func relative(bearing: Bearing?) -> Double? {
        bearing.map { bearing in
            precondition(bearing.reference == heading.reference, "bearing and heading reference mismatch")
            return (bearing - heading).degrees
        }
    }
}

#Preview {
    CDIView(heading: .init(angle: 277, reference: .magnetic),
            bearing: .init(angle: 218, reference: .magnetic),
            IPDirectBearing: .init(angle: 121, reference: .magnetic),
            targetDirectBearing: .init(angle: 213, reference: .magnetic),
            crossTrackDistance: .init(value: 1, unit: .nauticalMiles))
    .padding()
}
