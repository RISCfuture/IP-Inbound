import Foundation

struct FromToMath: Equatable {
  /// The bank angle the turn model flies. Shared with ``IPTargetMath``'s run-in sequencing, which
  /// sizes its buffer from the same turn geometry.
  static let bankAngle = Measurement(value: 30, unit: UnitAngle.degrees)

  /// Turns below this angle are treated as instantaneous: the turn geometry adds no meaningful time
  /// or forward progress, so the straight-line solution stands.
  private static let smallTurn = Measurement(value: 10, unit: UnitAngle.degrees)
  private static let minimumTimeToTOT = Measurement(value: 1, unit: UnitDuration.seconds)

  /// The lateral acceleration a level turn at ``bankAngle`` pulls: `g·tan(bank)`. Turn rate is this
  /// divided by ground speed, so `speed / turnAcceleration` is the time to turn one radian. Doubles
  /// as the maneuver envelope elsewhere, since it is the strongest acceleration the guidance models
  /// the aircraft applying.
  static var turnAcceleration: Measurement<UnitAcceleration> {
    Measurement.gravity * tan(bankAngle.radians)
  }

  var from: Coordinate
  let to: Coordinate

  var speed: Measurement<UnitSpeed>

  var track: Bearing
  var trackMagnetic: Bearing {
    track.toMagnetic(declination: declination)
  }

  let targetSpeed: Measurement<UnitSpeed>
  let timeOnTarget: Date
  let now: Date

  var bearing: Bearing { from.bearing(to: to) }  // deg
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

    // If turn is small, ignore turn geometry
    guard turnAngle > Self.smallTurn else {
      return distance / speed
    }

    // Total time = time spent turning + time for the distance the turn doesn't already cover
    return turnTime + ((distance - Self.turnChord(angle: turnAngle, speed: speed)) / speed)
  }
  var timeOfArrival: Date { timeToGo.after(date: now) }
  var deltaTOT: Measurement<UnitDuration> { timeOfArrival - timeOnTarget }

  var isLate: Bool { deltaTOT > .zero }
  var isEarly: Bool { deltaTOT < .zero }

  /// The turn required to roll out on the bearing to the destination, as a positive angle.
  private var turnAngle: Measurement<UnitAngle> {
    (bearingMagnetic - trackMagnetic).normalized.absoluteValue.angle
  }

  /// Ground speed needed to reach the destination (`to`) exactly at its run-to time
  /// (`timeOnTarget`), accounting for the time spent turning onto the bearing — the same turn model
  /// as ``timeToGo`` — so the callout agrees with the early/late timing. Returns `nil` when the
  /// remaining time is at or below a small epsilon (run-to time already passed or imminent), or when
  /// no finite speed can make the time because the required turn alone overruns it.
  var requiredGroundSpeed: Measurement<UnitSpeed>? {
    let timeToTOT = timeOnTarget - now
    guard timeToTOT > Self.minimumTimeToTOT else { return nil }

    // A turn under the threshold adds no meaningful penalty, so the straight-line speed makes it.
    guard turnAngle > Self.smallTurn else { return distance / timeToTOT }

    return Self.turnAwareSpeed(distance: distance, time: timeToTOT, angle: turnAngle)
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
    let angle = (toHeading - fromHeading).normalized.absoluteValue.angle

    guard angle > smallTurn else { return .zero }

    // Turn rate is `turnAcceleration / speed`, so the time to sweep the angle is its reciprocal
    // scaled by the angle in radians.
    return speed / turnAcceleration * angle.radians
  }

  /// The straight-line progress a turn through `angle` makes toward the destination: the chord of the
  /// arc flown, `2·r·sin(θ/2)`, at the level-turn radius for `speed`.
  private static func turnChord(
    angle: Measurement<UnitAngle>,
    speed: Measurement<UnitSpeed>
  ) -> Measurement<UnitLength> {
    // During a constant-rate turn the aircraft follows a circular arc of radius r = v²/(g·tan(bank)).
    let turnRadius = speed / turnAcceleration * speed
    return turnRadius * (2 * sin(angle.radians / 2))
  }

  /// Solves `timeToGo(v) == time` for the ground speed `v`. Turning onto the bearing both consumes
  /// time and shortens the remaining straight-line distance (chord progress), so `timeToGo` reduces
  /// to `distance / v + c·v` and the speed is the smaller positive root of
  /// `c·v² − time·v + distance = 0`. Returns `nil` when no real root exists — the turn alone overruns
  /// the available time, so no finite speed makes it.
  private static func turnAwareSpeed(
    distance: Measurement<UnitLength>,
    time: Measurement<UnitDuration>,
    angle: Measurement<UnitAngle>
  ) -> Measurement<UnitSpeed>? {
    let radians = angle.radians
    let accelerationMSS = turnAcceleration.converted(to: .metersPerSecondSquared).value
    let c = (radians - 2 * sin(radians / 2)) / accelerationMSS
    guard c > 0 else { return distance / time }

    let distanceM = distance.converted(to: .meters).value
    let timeS = time.converted(to: .seconds).value
    let discriminant = timeS * timeS - 4 * c * distanceM
    guard discriminant >= 0 else { return nil }

    return .init(value: (timeS - discriminant.squareRoot()) / (2 * c), unit: .metersPerSecond)
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.from == rhs.from && lhs.to == rhs.to && lhs.speed == rhs.speed
      && lhs.targetSpeed == rhs.targetSpeed && lhs.timeOnTarget == rhs.timeOnTarget
  }
}
