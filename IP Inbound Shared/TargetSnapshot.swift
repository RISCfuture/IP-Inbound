import Foundation
import MeasurementKit
import MeasurementKitLocation

/// A `Codable`, value-type copy of a target's guidance geometry, suitable for transmitting to the
/// Apple Watch over WatchConnectivity. Conforms to ``GuidanceTarget`` so the watch drives the same
/// run-in math as the iPhone, computed against the watch's own GPS.
struct TargetSnapshot: GuidanceTarget, Codable, Sendable, Equatable, Identifiable {
  let id: String
  let name: String
  let latitude: Double
  let longitude: Double
  let offsetBearing: Double  // deg
  let offsetBearingIsTrue: Bool
  let offsetDistance: Double  // NM
  let targetGroundSpeed: Double  // kt
  let timeOnTarget: Date?
  let declination: Double  // deg

  var coordinate: Coordinate {
    .init(latitude: latitude, longitude: longitude)
  }
  var offsetBearingMeasurement: OffsetBearing {
    .init(degrees: offsetBearing, isTrue: offsetBearingIsTrue)
  }
  var offsetDistanceMeasurement: Measurement<UnitLength> {
    .init(value: offsetDistance, unit: .nauticalMiles)
  }
  var targetGroundSpeedMeasurement: Measurement<UnitSpeed> {
    .init(value: targetGroundSpeed, unit: .knots)
  }
  var declinationMeasurement: Measurement<UnitAngle> {
    .init(value: declination, unit: .degrees)
  }
}
