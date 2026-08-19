import CoreLocation
import Foundation
import MeasurementKit
import MeasurementKitLocation

enum Guidance {
  case toIPWithSpeedGuidance
  case toIPWithCountdown
  case toTarget
  case toTargetBypassingIP
  case countdownOnly
  case postPass
}

struct GuidanceHelper<T: GuidanceTarget> {
  // Minimum speed threshold for movement detection (vs on ground)
  private static var movementThreshold: Measurement<UnitSpeed> {
    .init(value: 30, unit: .knots)
  }

  /// How far ahead of the desired IP-crossing time counts as arriving early enough to hold off with a
  /// countdown rather than fly speed guidance.
  private static var earlyArrivalThreshold: Measurement<UnitDuration> {
    .init(value: 60, unit: .seconds)
  }

  private let math: IPTargetMath<T>
  private let target: T

  /// The aircraft's ground speed, as the guidance math sees it. A fix that reports no speed is
  /// treated as stopped, which is what the on-ground countdown wants.
  private let groundSpeed: Measurement<UnitSpeed>

  // Computed predicates for clear logic
  var isMoving: Bool { groundSpeed > Self.movementThreshold }

  var isPastIP: Bool { math.isPastIP }

  var isPastTarget: Bool { math.isPastTarget }

  var isAfterTOT: Bool { math.isAfterTOT }

  // Timing calculations
  var ipDeltaTime: Measurement<UnitDuration> { math.IPDeltaTime ?? .zero }

  // More than the early-arrival threshold ahead of the IP at current speed
  var wouldArriveEarlyAtIP: Bool { ipDeltaTime < -Self.earlyArrivalThreshold }

  var wouldArriveLateEvenAtMaxSpeed: Bool {
    if let fastestETA = math.pposToIPToTargetETAAtMaxSpeed,
      let timeOnTarget = target.timeOnTarget
    {
      return fastestETA > timeOnTarget
    }
    return false
  }

  var guidance: Guidance {
    // Not moving - just show countdown
    if !isMoving { return .countdownOnly }

    // Past the target AND past TOT - show how the pass went and offer the
    // next target. Crossing the target before TOT (an early arrival on a
    // holding pattern) keeps the IP→Target guidance until the planned time
    // elapses.
    if isPastTarget, isAfterTOT { return .postPass }

    // After IP - show IP to target guidance with CDI cross-track deviation and relative time indicator
    if isPastIP { return .toTarget }

    // Prior to IP - determine guidance mode based on timing
    guard math.IPDeltaTime != nil, target.timeOnTarget != nil else {
      return .countdownOnly
    }

    // If more than 60 seconds early at current speed - show PPOS to IP with countdown timer (no CDI deviation)
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
  init?(location: CLLocation, target: T, now: Date) {
    guard let math = IPTargetMath(location: location, target: target, now: now) else { return nil }
    self.init(math: math, location: location, target: target)
  }

  init(math: IPTargetMath<T>, location: CLLocation, target: T) {
    self.math = math
    self.target = target
    self.groundSpeed = location.groundSpeed ?? .zero
  }
}
