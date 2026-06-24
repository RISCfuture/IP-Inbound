import CoreLocation
import Foundation

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
  private static var movementThreshold: Double {
    Measurement(value: 30, unit: UnitSpeed.knots).converted(to: .metersPerSecond).value
  }

  private let math: IPTargetMath<T>
  private let location: CLLocation
  private let target: T

  // Computed predicates for clear logic
  var isMoving: Bool { location.speed > Self.movementThreshold }

  var isPastIP: Bool { math.isPastIP }

  var isPastTarget: Bool { math.isPastTarget }

  var isAfterTOT: Bool { math.isAfterTOT }

  // Timing calculations
  var ipDeltaTime: TimeInterval { math.IPDeltaTime ?? 0 }

  // More than 60 seconds early at current speed
  var wouldArriveEarlyAtIP: Bool { ipDeltaTime < -60 }

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

  init(location: CLLocation, target: T, now: Date) {
    self.location = location
    self.target = target
    self.math = IPTargetMath(location: location, target: target, now: now)
  }

  init(math: IPTargetMath<T>, location: CLLocation, target: T) {
    self.math = math
    self.location = location
    self.target = target
  }
}
