import Foundation
import MeasurementKit
import MeasurementKitLocation

/// The geometry of a run-in target as the guidance math consumes it: where the target is, how the
/// initial point (IP) is offset from it, the planned run-in ground speed and time-on-target, and the
/// local magnetic declination.
///
/// The persisted `Target` (iPhone) and the wire-transmitted ``TargetSnapshot`` (Apple Watch) both
/// conform, so ``IPTargetMath`` and ``GuidanceHelper`` drive identical guidance on either platform.
protocol GuidanceTarget {
  var coordinate: Coordinate { get }
  var offsetBearingMeasurement: OffsetBearing { get }
  var offsetDistanceMeasurement: Measurement<UnitLength> { get }
  var targetGroundSpeedMeasurement: Measurement<UnitSpeed> { get }
  var declinationMeasurement: Measurement<UnitAngle> { get }
  var timeOnTarget: Date? { get }
}

// MARK: - Derived run-in geometry

extension GuidanceTarget {
  /// Fraction of ground-speed increase allowable from the run-in speed when catching up to a late
  /// time-on-target.
  static var allowableSpeedVariance: Double { 0.1 }

  /// The initial point: the target offset by the run-in bearing and distance.
  var IPCoordinate: Coordinate {
    coordinate.offset(
      bearing: offsetBearingMeasurement.toTrue(variation: declinationMeasurement),
      distance: offsetDistanceMeasurement
    )
  }

  /// The run-in leg, from the initial point to the target.
  var IPToTarget: GreatCircleSegment {
    .init(from: IPCoordinate, to: coordinate)
  }

  /// The run-in track: the reciprocal of the offset bearing (IP toward target).
  var desiredTrack: OffsetBearing { offsetBearingMeasurement.reciprocal }
  var desiredTrackMagnetic: MagneticBearing {
    desiredTrack.toMagnetic(variation: declinationMeasurement)
  }
  var desiredTrackTrue: TrueBearing { desiredTrack.toTrue(variation: declinationMeasurement) }

  /// When the aircraft should cross the IP to make its time-on-target at the planned ground speed.
  var desiredTimeOverIP: Date? {
    let runInTime = IPToTarget.length / targetGroundSpeedMeasurement
    return timeOnTarget.map { $0 - runInTime }
  }

  /// The latest the aircraft may cross the IP and still make its time-on-target, flying the run-in at
  /// the maximum allowable ground speed.
  var maxAllowableTimeOverIP: Date? {
    let runInTime = IPToTarget.length / maxAllowableGroundSpeed
    return timeOnTarget.map { $0 - runInTime }
  }

  /// The fastest run-in ground speed the guidance will plan to, above which the aircraft is
  /// considered unable to make its time-on-target.
  var maxAllowableGroundSpeed: Measurement<UnitSpeed> {
    targetGroundSpeedMeasurement * (1 + Self.allowableSpeedVariance)
  }
}
