public import Foundation
import MeasurementKit
public import MeasurementKitLocation

/// The geometry of a run-in target as the guidance math consumes it: where the target is, how the
/// initial point (IP) is offset from it, the planned run-in ground speed and time-on-target, and the
/// local magnetic declination.
///
/// The persisted `Target` (iPhone) and the wire-transmitted ``TargetSnapshot`` (Apple Watch) both
/// conform, so ``IPTargetMath`` and ``GuidanceHelper`` drive identical guidance on either platform.
public protocol GuidanceTarget {
  /// Where the target is.
  var coordinate: Coordinate { get }

  /// The direction from the target to the initial point, in the datum the pilot entered.
  var offsetBearingMeasurement: OffsetBearing { get }

  /// How far the initial point lies from the target.
  var offsetDistanceMeasurement: Measurement<UnitLength> { get }

  /// The ground speed the run-in is planned at.
  var targetGroundSpeedMeasurement: Measurement<UnitSpeed> { get }

  /// The magnetic declination at the target.
  var declinationMeasurement: Measurement<UnitAngle> { get }

  /// The briefed time on target, or `nil` when none has been set.
  var timeOnTarget: Date? { get }
}

// MARK: - Derived run-in geometry

extension GuidanceTarget {
  /// Fraction of ground-speed increase allowable from the run-in speed when catching up to a late
  /// time-on-target.
  public static var allowableSpeedVariance: Double { 0.1 }

  /// How long past the briefed time on target a run stays one anybody is flying.
  ///
  /// Long enough that a badly late pass, or a pilot still reading their result, is never cut off
  /// mid-thought; short enough that a run cannot outlive the sortie it belongs to.
  public static var postTOTGrace: Measurement<UnitDuration> { .init(value: 15, unit: .minutes) }

  /// The initial point: the target offset by the run-in bearing and distance.
  public var IPCoordinate: Coordinate {
    coordinate.offset(
      bearing: offsetBearingMeasurement.toTrue(variation: declinationMeasurement),
      distance: offsetDistanceMeasurement
    )
  }

  /// The run-in leg, from the initial point to the target.
  public var IPToTarget: GreatCircleSegment {
    .init(from: IPCoordinate, to: coordinate)
  }

  /// The run-in track: the reciprocal of the offset bearing (IP toward target).
  public var desiredTrack: OffsetBearing { offsetBearingMeasurement.reciprocal }
  /// The run-in track, measured from magnetic north.
  public var desiredTrackMagnetic: MagneticBearing {
    desiredTrack.toMagnetic(variation: declinationMeasurement)
  }
  /// The run-in track, measured from true north.
  public var desiredTrackTrue: TrueBearing {
    desiredTrack.toTrue(variation: declinationMeasurement)
  }

  /// When the aircraft should cross the IP to make its time-on-target at the planned ground speed.
  public var desiredTimeOverIP: Date? {
    let runInTime = IPToTarget.length / targetGroundSpeedMeasurement
    return timeOnTarget.map { $0 - runInTime }
  }

  /// The stretch of the run the pilot actually wants the countdown in front of them for: from the
  /// time they should cross the IP through the time on target.
  ///
  /// `nil` when no time on target is briefed, and when the run-in leg does not resolve to a finite
  /// duration — a target with no ground speed divides to infinity, and a range built from that is
  /// not a window anyone can be shown.
  public var runInWindow: ClosedRange<Date>? {
    guard let timeOnTarget, let desiredTimeOverIP,
      desiredTimeOverIP.timeIntervalSince(timeOnTarget).isFinite,
      desiredTimeOverIP <= timeOnTarget
    else { return nil }
    return desiredTimeOverIP...timeOnTarget
  }

  /// When the run stops being one anybody is flying, and everything it holds is released: the
  /// background location session, the countdown on the Lock Screen and on the watch face, and the
  /// guidance's offer to fly it.
  ///
  /// `nil` when no time on target is briefed — a target with no plan has no run to expire.
  public var runExpiry: Date? { timeOnTarget.map { $0 + Self.postTOTGrace } }

  /// The latest the aircraft may cross the IP and still make its time-on-target, flying the run-in at
  /// the maximum allowable ground speed.
  public var maxAllowableTimeOverIP: Date? {
    let runInTime = IPToTarget.length / maxAllowableGroundSpeed
    return timeOnTarget.map { $0 - runInTime }
  }

  /// The fastest run-in ground speed the guidance will plan to, above which the aircraft is
  /// considered unable to make its time-on-target.
  public var maxAllowableGroundSpeed: Measurement<UnitSpeed> {
    targetGroundSpeedMeasurement * (1 + Self.allowableSpeedVariance)
  }

  /// Whether the run is over at `now`.
  ///
  /// A target with no time on target has no run to be over: it has nothing to expire, and answering
  /// `true` would have every surface read an unbriefed target as stale rather than as unstarted.
  ///
  /// - Parameter now: the moment to judge the run against.
  /// - Returns: `true` once the run's expiry has arrived.
  public func hasRunExpired(at now: Date) -> Bool {
    guard let runExpiry else { return false }
    return now >= runExpiry
  }
}
