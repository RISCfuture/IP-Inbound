import Foundation
import MeasurementKit
import MeasurementKitLocation

/// A `Codable`, value-type copy of a target's guidance geometry, suitable for transmitting to the
/// Apple Watch over WatchConnectivity. Conforms to ``GuidanceTarget`` so the watch drives the same
/// run-in math as the iPhone, computed against the watch's own GPS.
public struct TargetSnapshot: GuidanceTarget, Codable, Sendable, Equatable, Identifiable {
  public let id: String
  public let name: String
  public let latitude: Double
  public let longitude: Double
  public let offsetBearing: Double  // deg
  public let offsetBearingIsTrue: Bool
  public let offsetDistance: Double  // NM
  public let targetGroundSpeed: Double  // kt
  public let timeOnTarget: Date?
  public let declination: Double  // deg

  public var coordinate: Coordinate {
    .init(latitude: latitude, longitude: longitude)
  }
  public var offsetBearingMeasurement: OffsetBearing {
    .init(degrees: offsetBearing, isTrue: offsetBearingIsTrue)
  }
  public var offsetDistanceMeasurement: Measurement<UnitLength> {
    .init(value: offsetDistance, unit: .nauticalMiles)
  }
  public var targetGroundSpeedMeasurement: Measurement<UnitSpeed> {
    .init(value: targetGroundSpeed, unit: .knots)
  }
  public var declinationMeasurement: Measurement<UnitAngle> {
    .init(value: declination, unit: .degrees)
  }

  /// Copies a target's guidance geometry into a value the watch can be sent.
  public init(
    id: String,
    name: String,
    latitude: Double,
    longitude: Double,
    offsetBearing: Double,
    offsetBearingIsTrue: Bool,
    offsetDistance: Double,
    targetGroundSpeed: Double,
    timeOnTarget: Date?,
    declination: Double
  ) {
    self.id = id
    self.name = name
    self.latitude = latitude
    self.longitude = longitude
    self.offsetBearing = offsetBearing
    self.offsetBearingIsTrue = offsetBearingIsTrue
    self.offsetDistance = offsetDistance
    self.targetGroundSpeed = targetGroundSpeed
    self.timeOnTarget = timeOnTarget
    self.declination = declination
  }
}
