import Defaults
import MeasurementKit
import MeasurementKitLocation
import SwiftUI

struct CDIView: View {
  /// Full-scale needle travel, as a fraction of the rose's radius.
  private static let fullScaleRadiusFraction = 0.75
  private static let compassRoseLineWidth: CGFloat = 2,
    lubberLineWidth: CGFloat = 5

  private static let trackColor = Color.purple,
    ipColor = Color.yellow,
    targetColor = Color.red

  var track: MagneticBearing
  var bearing: MagneticBearing?
  var bearingColor = Color.accentColor
  var IPDirectBearing: MagneticBearing?
  var targetDirectBearing: MagneticBearing?
  /// Where the aircraft lies relative to the run-in course. `nil` in the phases that steer toward
  /// the IP, which have no course line to deviate from, and draws the bar without its deflected
  /// segment.
  var deviation: CourseDeviation?

  @Default(.distanceUnit)
  private var distanceDefault

  var body: some View {
    GeometryReader { geo in
      let radius = min(geo.size.width, geo.size.height) / 2
      let center = geo.size.center

      ZStack {
        Text("TRK")
          .foregroundStyle(Self.trackColor)
          .fontWeight(.bold)
          .accessibilityHidden(true)

        FixedRotatingView(targetAngle: -track.degrees) { angle in
          Group {
            CompassRose()
              .stroke(lineWidth: Self.compassRoseLineWidth)
            CompassNumbers(rotation: track.degrees)
              .drawingGroup()
          }
          .rotationEffect(.degrees(angle))
        }
        .accessibilityHidden(true)

        if let ipRelative = relative(bearing: IPDirectBearing) {
          CDIDirectPointerLayer(
            relativeAngle: ipRelative,
            label: "IP",
            color: Self.ipColor,
            accessibilityDescription: "Direction to initial point",
            radius: radius,
            center: center,
            animatesRotation: true
          )
        }

        if let targetRelative = relative(bearing: targetDirectBearing) {
          CDIDirectPointerLayer(
            relativeAngle: targetRelative,
            label: "T",
            color: Self.targetColor,
            accessibilityDescription: "Direction to target",
            radius: radius,
            center: center
          )
        }

        if let relativeBearing = relative(bearing: bearing) {
          CDIBearingPointerLayer(
            relativeAngle: relativeBearing,
            needleOffset: deviation?.needleOffset,
            fullScaleRadiusFraction: Self.fullScaleRadiusFraction,
            bearingColor: bearingColor
          )
        }

        LubberLine()
          .stroke(.accent, lineWidth: Self.lubberLineWidth)
          .drawingGroup()
          .accessibilityHidden(true)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text("Course deviation indicator"))
    .accessibilityValue(Text(accessibilityValue))
  }

  private func relative(bearing: MagneticBearing?) -> Double? {
    bearing.map { ($0 - track).degrees }
  }
}

extension CDIView {
  private var accessibilityValue: String {
    var components = [String]()

    components.append(
      String(localized: "Track \(track, format: .bearing).")
    )

    if let bearing {
      components.append(
        String(localized: "Bearing \(bearing, format: .bearing).")
      )
    }

    if let deviation {
      components.append(deviation.announcement(in: distanceDefault.distanceUnit))
    }

    return components.joined(separator: " ")
  }
}

#Preview("Full deflection right") {
  CDIView(
    track: MagneticBearing(degrees: 277),
    bearing: MagneticBearing(degrees: 218),
    IPDirectBearing: MagneticBearing(degrees: 121),
    targetDirectBearing: MagneticBearing(degrees: 213),
    deviation: .init(crossTrackDistance: CourseDeviation.fullScale)
  )
  .padding()
}

#Preview("Half deflection left") {
  CDIView(
    track: MagneticBearing(degrees: 277),
    bearing: MagneticBearing(degrees: 218),
    IPDirectBearing: MagneticBearing(degrees: 121),
    targetDirectBearing: MagneticBearing(degrees: 213),
    deviation: .init(crossTrackDistance: .init(value: -2, unit: .nauticalMiles))
  )
  .padding()
}

#Preview("Over scale left") {
  CDIView(
    track: MagneticBearing(degrees: 360),
    bearing: MagneticBearing(degrees: 30),
    IPDirectBearing: MagneticBearing(degrees: 121),
    targetDirectBearing: MagneticBearing(degrees: 213),
    deviation: .init(crossTrackDistance: .init(value: -8, unit: .nauticalMiles))
  )
  .padding()
}

#Preview("No bearing") {
  CDIView(
    track: MagneticBearing(degrees: 90),
    bearing: nil,
    IPDirectBearing: nil,
    targetDirectBearing: nil,
    deviation: nil
  )
  .padding()
}
