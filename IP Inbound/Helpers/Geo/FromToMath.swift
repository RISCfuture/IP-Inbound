import Foundation

struct FromToMath: Equatable {
  private static let bankAngle = Measurement(value: 45, unit: UnitAngle.degrees)
    .converted(to: .radians).value
  private static let smallTurn = Measurement(value: 10, unit: UnitAngle.degrees)
    .converted(to: .radians).value
  private static let g = Measurement(value: 1, unit: UnitAcceleration.gravity)
    .converted(to: .metersPerSecondSquared).value
  private static let minimumTimeToTOT = Measurement(value: 1, unit: UnitDuration.seconds)

  var from: Coordinate
  let to: Coordinate

  var speed: Measurement<UnitSpeed>

  var track: Bearing
  var trackTrue: Bearing {
    track.toTrue(declination: declination)
  }
  var trackMagnetic: Bearing {
    track.toMagnetic(declination: declination)
  }

  let targetSpeed: Measurement<UnitSpeed>
  let timeOnTarget: Date
  let now: Date

  var bearing: Bearing { from.bearing(to: to) }  // deg
  var bearingTrue: Bearing {
    bearing.toTrue(declination: declination)
  }
  var bearingMagnetic: Bearing {
    bearing.toMagnetic(declination: declination)
  }

  var distance: Measurement<UnitLength> { from.distance(to: to) }
  var timeToGo: Measurement<UnitDuration> {
    let turnTime = Self.turnTime(
      fromHeading: trackMagnetic,
      toHeading: bearingMagnetic,
      speed: speed
    )

    let deltaAngle = abs((bearingMagnetic - trackMagnetic).normalized.radians)

    // If turn is small, ignore turn geometry
    guard deltaAngle > Self.smallTurn else {
      return distance / speed
    }

    // Calculate forward progress made during the turn using chord length
    // During a constant-rate turn, the aircraft follows a circular arc
    // Turn radius: r = v²/(g*tan(bankAngle))
    let speedMS = speed.converted(to: .metersPerSecond).value
    let turnRadius = (speedMS * speedMS) / (Self.g * tan(Self.bankAngle))

    // Forward progress toward destination (chord length of the arc)
    // Using the formula: chord = 2 * r * sin(θ/2)
    let chordLength = 2 * turnRadius * sin(deltaAngle / 2)

    // Remaining distance after accounting for forward progress during turn
    let remainingDistance = Measurement(
      value: distance.converted(to: .meters).value - chordLength,
      unit: UnitLength.meters
    )

    // Total time = time spent turning + time for remaining distance
    return turnTime + (remainingDistance / speed)
  }
  var timeOfArrival: Date { timeToGo.after(date: now) }
  var deltaTOT: TimeInterval {
    timeOfArrival.timeIntervalSince(timeOnTarget)
  }

  var deltaTOTMeasurement: Measurement<UnitDuration> {
    .init(value: deltaTOT, unit: .seconds)
  }

  var isLate: Bool { deltaTOT > 0 }
  var isEarly: Bool { deltaTOT < 0 }

  /// Ground speed needed to reach the destination (`to`) exactly at its run-to time
  /// (`timeOnTarget`), accounting for the time spent turning onto the bearing — the same turn model
  /// as ``timeToGo`` — so the callout agrees with the early/late timing. Returns `nil` when the
  /// remaining time is at or below a small epsilon (run-to time already passed or imminent), or when
  /// no finite speed can make the time because the required turn alone overruns it.
  var requiredGroundSpeed: Measurement<UnitSpeed>? {
    let timeToTOTSeconds = timeOnTarget.timeIntervalSince(now)
    guard timeToTOTSeconds > Self.minimumTimeToTOT.converted(to: .seconds).value else { return nil }

    let distanceM = distance.converted(to: .meters).value
    let deltaAngle = abs((bearingMagnetic - trackMagnetic).normalized.radians)

    // A turn under the threshold adds no meaningful penalty, so the straight-line speed makes it.
    guard deltaAngle > Self.smallTurn else {
      return .init(value: distanceM / timeToTOTSeconds, unit: .metersPerSecond)
    }

    guard
      let speedMS = Self.turnAwareSpeedMS(
        distanceM: distanceM,
        timeS: timeToTOTSeconds,
        deltaAngle: deltaAngle
      )
    else { return nil }
    return .init(value: speedMS, unit: .metersPerSecond)
  }

  private let declination: Measurement<UnitAngle>

  init(
    from: Coordinate,
    to: Coordinate,
    speed: Measurement<UnitSpeed>,
    track: Bearing,
    targetSpeed: Measurement<UnitSpeed>,
    timeOnTarget: Date,
    declination: Measurement<UnitAngle>,
    now: Date
  ) {
    self.from = from
    self.to = to
    self.speed = speed
    self.track = track
    self.targetSpeed = targetSpeed
    self.timeOnTarget = timeOnTarget
    self.declination = declination
    self.now = now
  }

  static func turnAnticipationDistance(
    fromHeading: Bearing,
    toHeading: Bearing,
    speed: Measurement<UnitSpeed>
  ) -> Measurement<UnitLength> {
    let turnTimeRequired = turnTime(fromHeading: fromHeading, toHeading: toHeading, speed: speed)
    let turnDistance = speed * turnTimeRequired * 0.5
    return turnDistance.converted(to: .nauticalMiles)
  }

  static func turnTime(
    fromHeading: Bearing,
    toHeading: Bearing,
    speed: Measurement<UnitSpeed>
  ) -> Measurement<UnitDuration> {
    let deltaAngle = abs((toHeading - fromHeading).normalized.radians)

    guard deltaAngle > smallTurn else { return .init(value: 0, unit: .seconds) }

    let turnRate = g * tan(bankAngle) / speed.converted(to: .metersPerSecond).value
    let turnTimeS = deltaAngle / turnRate

    return Measurement(value: turnTimeS, unit: .seconds)
  }

  /// Solves `timeToGo(v) == timeS` for the ground speed `v`, in m/s. Turning onto the bearing both
  /// consumes time and shortens the remaining straight-line distance (chord progress), so `timeToGo`
  /// reduces to `distanceM / v + c·v` and the speed is the smaller positive root of
  /// `c·v² − timeS·v + distanceM = 0`. Returns `nil` when no real root exists — the turn alone
  /// overruns the available time, so no finite speed makes it.
  private static func turnAwareSpeedMS(
    distanceM: Double,
    timeS: Double,
    deltaAngle: Double
  ) -> Double? {
    let c = (deltaAngle - 2 * sin(deltaAngle / 2)) / (g * tan(bankAngle))
    guard c > 0 else { return distanceM / timeS }

    let discriminant = timeS * timeS - 4 * c * distanceM
    guard discriminant >= 0 else { return nil }

    return (timeS - discriminant.squareRoot()) / (2 * c)
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.from == rhs.from && lhs.to == rhs.to && lhs.speed == rhs.speed
      && lhs.targetSpeed == rhs.targetSpeed && lhs.timeOnTarget == rhs.timeOnTarget
  }
}
