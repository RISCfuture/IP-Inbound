import Foundation

struct FromToMath: Equatable {
  private static let bankAngle = Measurement(value: 45, unit: UnitAngle.degrees)
    .converted(to: .radians).value
  private static let smallTurn = Measurement(value: 10, unit: UnitAngle.degrees)
    .converted(to: .radians).value
  private static let g = Measurement(value: 1, unit: UnitAcceleration.gravity)
    .converted(to: .metersPerSecondSquared).value

  var from: Coordinate
  let to: Coordinate

  var speed: Measurement<UnitSpeed>

  var track: Bearing
  var trackMagnetic: Bearing {
    track.toMagnetic(declination: declination)
  }

  let targetSpeed: Measurement<UnitSpeed>
  let timeOnTarget: Date

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
  var timeOfArrival: Date { timeToGo.afterNow }
  var deltaTOT: TimeInterval {
    timeOfArrival.timeIntervalSince(timeOnTarget)
  }

  var isLate: Bool { deltaTOT > 0 }
  var isEarly: Bool { deltaTOT < 0 }

  private let declination: Measurement<UnitAngle>

  init(
    from: Coordinate,
    to: Coordinate,
    speed: Measurement<UnitSpeed>,
    track: Bearing,
    targetSpeed: Measurement<UnitSpeed>,
    timeOnTarget: Date,
    declination: Measurement<UnitAngle>
  ) {
    self.from = from
    self.to = to
    self.speed = speed
    self.track = track
    self.targetSpeed = targetSpeed
    self.timeOnTarget = timeOnTarget
    self.declination = declination
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

  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.from == rhs.from && lhs.to == rhs.to && lhs.speed == rhs.speed
      && lhs.targetSpeed == rhs.targetSpeed && lhs.timeOnTarget == rhs.timeOnTarget
  }
}
