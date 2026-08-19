import MeasurementKit
import MeasurementKitLocation
import SwiftUI

struct CDIView: View {
  private static let scaleWidth = 0.75  // fraction of radius
  private static let compassRoseLineWidth: CGFloat = 2,
    lubberLineWidth: CGFloat = 5

  private static let trackColor = Color.purple,
    ipColor = Color.yellow,
    targetColor = Color.red

  var heading: MagneticBearing
  var bearing: MagneticBearing?
  var bearingColor = Color.accentColor
  var IPDirectBearing: MagneticBearing?
  var targetDirectBearing: MagneticBearing?
  var crossTrackDistance: Measurement<UnitLength>?
  var distanceScale = Measurement(value: 4, unit: UnitLength.nauticalMiles)

  private var deflection: CGFloat? {
    guard let crossTrackDistance else { return nil }

    let deflection = crossTrackDistance / distanceScale
    return min(deflection, 1.0)
  }

  var body: some View {
    GeometryReader { geo in
      let radius = min(geo.size.width, geo.size.height) / 2
      let center = geo.size.center

      ZStack {
        Text("TRK")
          .foregroundStyle(Self.trackColor)
          .fontWeight(.bold)
          .accessibilityHidden(true)

        FixedRotatingView(targetAngle: -heading.degrees) { angle in
          Group {
            CompassRose()
              .stroke(lineWidth: Self.compassRoseLineWidth)
            CompassNumbers(rotation: heading.degrees)
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
            deflection: deflection,
            scaleWidth: Self.scaleWidth,
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
    bearing.map { ($0 - heading).degrees }
  }
}

extension CDIView {
  private var accessibilityValue: String {
    var components = [String]()

    components.append(
      String(localized: "Track heading \(heading, format: .bearing).")
    )

    if let bearing {
      components.append(
        String(localized: "Bearing \(bearing, format: .bearing).")
      )
    }

    if let deviationDescription {
      components.append(deviationDescription)
    }

    return components.joined(separator: " ")
  }

  private var deviationDescription: String? {
    guard let crossTrackDistance else { return nil }

    let distance = crossTrackDistance.magnitude
    guard distance > .zero else { return String(localized: "On course.") }

    let formattedDistance = distance.formatted(distanceFormatStyle)

    if crossTrackDistance > .zero {
      return String(localized: "\(formattedDistance) right of course.")
    }
    return String(localized: "\(formattedDistance) left of course.")
  }
}

#Preview("Full deflection") {
  CDIView(
    heading: MagneticBearing(degrees: 277),
    bearing: MagneticBearing(degrees: 218),
    IPDirectBearing: MagneticBearing(degrees: 121),
    targetDirectBearing: MagneticBearing(degrees: 213),
    crossTrackDistance: .init(value: 1, unit: .nauticalMiles)
  )
  .padding()
}

#Preview("Maximum deflection") {
  CDIView(
    heading: MagneticBearing(degrees: 360),
    bearing: MagneticBearing(degrees: 30),
    IPDirectBearing: MagneticBearing(degrees: 121),
    targetDirectBearing: MagneticBearing(degrees: 213),
    crossTrackDistance: .init(value: 8, unit: .nauticalMiles)
  )
  .padding()
}

#Preview("No bearing") {
  CDIView(
    heading: MagneticBearing(degrees: 90),
    bearing: nil,
    IPDirectBearing: nil,
    targetDirectBearing: nil,
    crossTrackDistance: nil
  )
  .padding()
}
