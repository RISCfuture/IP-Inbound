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

  /// How far ahead of the time on target the run stops being distant, measured in run-in legs.
  ///
  /// The countdown ring's extent is a single leg, so any earlier than this it sits pinned full and a
  /// glance cannot tell a run five minutes out from one an hour out. Two legs gives the ring a whole
  /// leg of visible travel before the aircraft is due over the IP, and gives everything earlier a
  /// presentation of its own.
  public static var closingLegs: Double { 2 }

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

  /// How long the run-in leg takes to fly at the planned ground speed.
  ///
  /// Not always a duration anything can be scheduled against: a target briefed with no ground speed
  /// divides to infinity, and one with no offset distance either divides to nothing. Callers that
  /// build a date or an extent from this check it first.
  public var runInDuration: Measurement<UnitDuration> {
    IPToTarget.length / targetGroundSpeedMeasurement
  }

  /// When the aircraft should cross the IP to make its time-on-target at the planned ground speed.
  public var desiredTimeOverIP: Date? {
    timeOnTarget.map { $0 - runInDuration }
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

  /// When the run stops being distant: ``closingLegs`` run-in legs before the time on target, which
  /// is one leg's flying short of the IP.
  ///
  /// `nil` when no time on target is briefed, and when the run-in leg does not resolve to a finite
  /// duration — neither is a moment a timeline can be scheduled against.
  public var closingTime: Date? {
    let standoff = runInDuration * Self.closingLegs
    guard standoff.value.isFinite else { return nil }
    return timeOnTarget.map { $0 - standoff }
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

  /// Whether the run-in is near enough at `now` that a countdown carries more than the briefed time
  /// would.
  ///
  /// A run with no reachable ``closingTime`` never closes: a target briefed with no ground speed has
  /// no leg to scale a ring against, so its time on target is all there is to show.
  ///
  /// - Parameter now: the moment to judge the run against.
  /// - Returns: `true` once the aircraft is within ``closingLegs`` legs of its time on target.
  public func isClosing(at now: Date) -> Bool {
    guard let closingTime else { return false }
    return now >= closingTime
  }

  /// Whether the briefed time on target has gone by at `now`.
  ///
  /// The run outlives its time on target by ``postTOTGrace``, so this is the stretch where there is
  /// still a run to show and nothing left to count toward.
  ///
  /// - Parameter now: the moment to judge the run against.
  /// - Returns: `true` once the time on target has passed.
  public func hasPassedTOT(at now: Date) -> Bool {
    guard let timeOnTarget else { return false }
    return now >= timeOnTarget
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
