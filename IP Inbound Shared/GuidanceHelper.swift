public import CoreLocation
public import Foundation
import MeasurementKit
import MeasurementKitLocation

/// Which phase of the run the aircraft is in, and therefore what the Fly screen shows.
public enum Guidance: Sendable {
  /// Inbound to the IP and on schedule: fly the speed the crossing time asks for.
  case toIPWithSpeedGuidance

  /// Inbound to the IP far enough ahead of schedule to hold off, so a countdown replaces the
  /// speed cue.
  case toIPWithCountdown

  /// Past the IP and running in on the target, steering the run-in course.
  case toTarget

  /// Too late to make the time-on-target by way of the IP, so the run goes direct to the target.
  case toTargetBypassingIP

  /// On the ground, or too slow to be flying a run: only the countdown to time-on-target is
  /// meaningful.
  case countdownOnly

  /// Past the target and past its time-on-target: the pass is flown and there is a result to show.
  case postPass
}

/// Reads a fix against a target's run-in geometry and says which phase of the run the aircraft is
/// in, so the phone and the watch draw the same screen from the same rules.
public struct GuidanceHelper<T: GuidanceTarget> {
  /// The ground speed above which the aircraft counts as flying rather than sitting on the ground.
  private static var movementThreshold: Measurement<UnitSpeed> {
    .init(value: 30, unit: .knots)
  }

  /// How far ahead of the desired IP-crossing time counts as arriving early enough to hold off with a
  /// countdown rather than fly speed guidance.
  private static var earlyArrivalEntryThreshold: Measurement<UnitDuration> {
    .init(value: 60, unit: .seconds)
  }

  /// How little of that lead has to remain before a countdown already running gives way to speed
  /// guidance.
  private static var earlyArrivalReleaseThreshold: Measurement<UnitDuration> {
    .init(value: 45, unit: .seconds)
  }

  private let math: IPTargetMath<T>
  private let target: T

  /// The phase the last fix put the aircraft in, or `nil` when this is the first fix of a run.
  private let previousGuidance: Guidance?

  /// The aircraft's ground speed, as the guidance math sees it. A fix that reports no speed is
  /// treated as stopped, which is what the on-ground countdown wants.
  private let groundSpeed: Measurement<UnitSpeed>

  /// Whether the aircraft is flying rather than sitting on the ground.
  public var isMoving: Bool { groundSpeed > Self.movementThreshold }

  /// Whether the initial point is behind the aircraft.
  public var isPastIP: Bool { math.isPastIP }

  /// Whether the target is behind the aircraft.
  public var isPastTarget: Bool { math.isPastTarget }

  /// Whether the planned time-on-target has elapsed.
  public var isAfterTOT: Bool { math.isAfterTOT }

  /// Whether the run has outlived its time-on-target by more than the plan allows.
  public var isRunExpired: Bool { math.isRunExpired }

  /// How far the projected IP crossing falls from the time the plan wants it, negative when early.
  public var ipDeltaTime: Measurement<UnitDuration> { math.IPDeltaTime ?? .zero }

  /// Whether the aircraft is far enough ahead of its IP crossing to hold off rather than slow down.
  public var wouldArriveEarlyAtIP: Bool { ipDeltaTime < -earlyArrivalThreshold }

  /// The lead the aircraft has to hold to fly a countdown rather than speed guidance. A countdown
  /// already running keeps its place down to the smaller release threshold, so a fix-to-fix wobble of
  /// a few seconds cannot swap the countdown for speed guidance and back.
  private var earlyArrivalThreshold: Measurement<UnitDuration> {
    previousGuidance == .toIPWithCountdown
      ? Self.earlyArrivalReleaseThreshold : Self.earlyArrivalEntryThreshold
  }

  /// Whether the time-on-target is unmakeable by way of the IP, even at the fastest run-in speed
  /// the guidance will plan to.
  public var wouldArriveLateEvenAtMaxSpeed: Bool {
    if let fastestETA = math.pposToIPToTargetETAAtMaxSpeed,
      let timeOnTarget = target.timeOnTarget
    {
      return fastestETA > timeOnTarget
    }
    return false
  }

  /// The phase of the run the current fix puts the aircraft in.
  public var guidance: Guidance {
    // Not moving - just show countdown
    if !isMoving { return .countdownOnly }

    // Past the target AND past TOT - show how the pass went and offer the
    // next target. Crossing the target before TOT (an early arrival on a
    // holding pattern) keeps the IP→Target guidance until the planned time
    // elapses.
    if isPastTarget, isAfterTOT { return .postPass }

    // After IP - show IP to target guidance with CDI cross-track deviation and relative time indicator
    // A run-in already under way is the pilot's to finish however late it has run, so this stands
    // ahead of the expiry below.
    if isPastIP { return .toTarget }

    // Short of the IP with the tasking lapsed - every route to the target is later than the plan
    // tolerates, and steering one would dress a dead tasking up as a live one. The pass reads as
    // flown, which against the plan it is.
    if isRunExpired { return .postPass }

    // Prior to IP - determine guidance mode based on timing
    guard math.IPDeltaTime != nil, target.timeOnTarget != nil else {
      return .countdownOnly
    }

    // Early enough at current speed to hold off - show PPOS to IP with countdown timer (no CDI
    // deviation)
    if wouldArriveEarlyAtIP { return .toIPWithCountdown }

    // If late even at max speed - show direct-to-target guidance with CDI cross-track deviation
    if wouldArriveLateEvenAtMaxSpeed { return .toTargetBypassingIP }

    // Within timing window - show PPOS to IP guidance with speed control (no CDI deviation)
    return .toIPWithSpeedGuidance
  }

  /// The guidance for `location`, or `nil` when the fix carries no usable ground speed or course.
  ///
  /// - Parameters:
  ///   - location: the fix to solve from.
  ///   - target: the target being run in on.
  ///   - now: the current time.
  ///   - previousGuidance: the phase the last fix put the aircraft in, which the early-arrival
  ///     threshold widens against so a lead hovering at the boundary cannot flip the phase at fix
  ///     rate.
  public init?(location: CLLocation, target: T, now: Date, previousGuidance: Guidance? = nil) {
    guard let math = IPTargetMath(location: location, target: target, now: now) else { return nil }
    self.init(math: math, location: location, target: target, previousGuidance: previousGuidance)
  }

  /// Wraps guidance around geometry that has already been solved for this fix.
  ///
  /// - Parameters:
  ///   - math: the run-in geometry for `location`.
  ///   - location: the fix the geometry was solved from.
  ///   - target: the target being run in on.
  ///   - previousGuidance: the phase the last fix put the aircraft in, which the early-arrival
  ///     threshold widens against so a lead hovering at the boundary cannot flip the phase at fix
  ///     rate.
  public init(
    math: IPTargetMath<T>,
    location: CLLocation,
    target: T,
    previousGuidance: Guidance? = nil
  ) {
    self.math = math
    self.target = target
    self.groundSpeed = location.groundSpeed ?? .zero
    self.previousGuidance = previousGuidance
  }
}

// MARK: - Course Deviation

extension GuidanceHelper {
  /// The run-in course deviation, or `nil` in the phases that steer toward the IP rather than along
  /// the run-in course: short of the IP the aircraft is vectored to a point, not a line, so its
  /// offset from the extended centerline is not a number to fly.
  public var courseDeviation: CourseDeviation? {
    switch guidance {
      case .toTarget, .toTargetBypassingIP: math.courseDeviation
      case .toIPWithSpeedGuidance, .toIPWithCountdown, .countdownOnly, .postPass: nil
    }
  }
}
