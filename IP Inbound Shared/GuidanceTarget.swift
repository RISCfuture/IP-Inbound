import Foundation

/// The geometry of a run-in target as the guidance math consumes it: where the target is, how the
/// initial point (IP) is offset from it, the planned run-in ground speed and time-on-target, and the
/// local magnetic declination.
///
/// The persisted `Target` (iPhone) and the wire-transmitted ``TargetSnapshot`` (Apple Watch) both
/// conform, so ``IPTargetMath`` and ``GuidanceHelper`` drive identical guidance on either platform.
protocol GuidanceTarget {
  var coordinate: Coordinate { get }
  var offsetBearingMeasurement: Bearing { get }
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
    coordinate.offsetBy(
      bearing: offsetBearingMeasurement.toTrue(declination: declinationMeasurement).angle,
      distance: offsetDistanceMeasurement
    )
  }

  /// The run-in leg, from the initial point to the target.
  var IPToTarget: Line {
    .init(from: IPCoordinate, to: coordinate)
  }

  /// The run-in track: the reciprocal of the offset bearing (IP toward target).
  var desiredTrack: Bearing { offsetBearingMeasurement.reciprocal }
  var desiredTrackMagnetic: Bearing { desiredTrack.toMagnetic(declination: declinationMeasurement) }
  var desiredTrackTrue: Bearing { desiredTrack.toTrue(declination: declinationMeasurement) }

  /// When the aircraft should cross the IP to make its time-on-target at the planned ground speed.
  var desiredTimeOverIP: Date? {
    let runInTime = IPToTarget.length / targetGroundSpeedMeasurement
    return timeOnTarget?.addingTimeInterval(-runInTime.converted(to: .seconds).value)
  }

  /// The latest the aircraft may cross the IP and still make its time-on-target, flying the run-in at
  /// the maximum allowable ground speed.
  var maxAllowableTimeOverIP: Date? {
    let groundSpeed = targetGroundSpeedMeasurement * (1 + Self.allowableSpeedVariance)
    let runInTime = IPToTarget.length / groundSpeed
    return timeOnTarget?.addingTimeInterval(-runInTime.converted(to: .seconds).value)
  }
}
