import CoreLocation
import Foundation

struct IPTargetMath: Equatable {
  private static let closeToIPTime = Measurement(value: 1, unit: UnitDuration.minutes)
  private static let gravityMSS = 9.80665
  private static let runInBankAngle = Measurement(value: 45, unit: UnitAngle.degrees)
  private static let sequenceCutoffAngle = Measurement(value: 90, unit: UnitAngle.degrees)

  var coordinate: Coordinate
  var speed: Measurement<UnitSpeed>
  var course: Bearing
  let target: Target

  var pposToIP: FromToMath? {
    guard let timeOnTarget = target.timeOnTarget else { return nil }
    return .init(
      from: coordinate,
      to: target.IPCoordinate,
      speed: speed,
      track: course,
      targetSpeed: target.targetGroundSpeedMeasurement,
      timeOnTarget: timeOnTarget,
      declination: declination
    )
  }

  var pposToTarget: FromToMath? {
    guard let timeOnTarget = target.timeOnTarget else { return nil }
    return .init(
      from: coordinate,
      to: target.coordinate,
      speed: speed,
      track: course,
      targetSpeed: target.targetGroundSpeedMeasurement,
      timeOnTarget: timeOnTarget,
      declination: declination
    )
  }

  var IPToTarget: FromToMath? {
    guard let timeOnTarget = target.timeOnTarget else { return nil }
    return .init(
      from: target.IPCoordinate,
      to: target.IPCoordinate,
      speed: speed,
      track: target.desiredTrack,
      targetSpeed: target.targetGroundSpeedMeasurement,
      timeOnTarget: timeOnTarget,
      declination: declination
    )
  }

  var isPastIP: Bool {
    guard let signedAlongM = signedAlongTrackDistanceM, let bufferM else { return false }
    return signedAlongM >= bufferM
  }

  var IP_ETA: Date? { pposToIP?.timeOfArrival }

  var IPDeltaTime: TimeInterval? {
    guard let IP_ETA, let desiredTimeOverIP = target.desiredTimeOverIP else { return nil }
    return IP_ETA.timeIntervalSince(desiredTimeOverIP)
  }

  var latestIPDeltaTime: TimeInterval? {
    guard let IP_ETA, let desiredTimeOverIP = target.maxAllowableTimeOverIP else { return nil }
    return IP_ETA.timeIntervalSince(desiredTimeOverIP)
  }

  var crossTrackDistance: Measurement<UnitLength> {
    Coordinate.crosstrackDistance(from: coordinate, to: target.IPToTarget)
  }

  var pposToIPToTargetETAAtMaxSpeed: Date? {
    guard target.timeOnTarget != nil else { return nil }

    let maxSpeed = target.targetGroundSpeedMeasurement * (1 + Target.allowableSpeedVariance)

    // Time from PPOS to IP at max speed (including turn from current heading)
    let distanceToIP = coordinate.distance(to: target.IPCoordinate)
    let turnToIPTime = FromToMath.turnTime(
      fromHeading: course.toMagnetic(declination: declination),
      toHeading: coordinate.bearing(to: target.IPCoordinate).toMagnetic(declination: declination),
      speed: maxSpeed
    )
    let straightTimeToIP = distanceToIP / maxSpeed
    let totalTimeToIP = straightTimeToIP + turnToIPTime

    // Time from IP to Target at max speed
    let ipToTargetDistance = target.IPToTarget.length
    let straightTimeIPToTarget = ipToTargetDistance / maxSpeed

    // Calculate turn anticipation at IP
    // The bearing we'll be on when arriving at IP is from PPOS to IP
    let ipBearing = coordinate.bearing(to: target.IPCoordinate)
    let turnAtIPTime = FromToMath.turnTime(
      fromHeading: ipBearing.toMagnetic(declination: declination),
      toHeading: target.desiredTrackMagnetic,
      speed: maxSpeed
    )

    // Turn anticipation reduces total time (start turn before IP)
    let turnAnticipation = turnAtIPTime * 0.5

    // Total time = PPOS to IP + IP to Target - turn anticipation
    let totalTime = totalTimeToIP + straightTimeIPToTarget - turnAnticipation

    return Date.now.addingTimeInterval(totalTime.converted(to: .seconds).value)
  }

  private var declination: Measurement<UnitAngle> { target.declinationMeasurement }

  init(coordinate: Coordinate, speed: Measurement<UnitSpeed>, course: Bearing, target: Target) {
    self.coordinate = coordinate
    self.speed = speed
    self.course = course
    self.target = target
  }

  init(location: CLLocation, target: Target) {
    self.init(
      coordinate: .init(location.coordinate),
      speed: .init(value: location.speed, unit: .metersPerSecond),
      course: .init(angle: location.course, reference: .true),
      target: target
    )
  }
}

// MARK: - IP Sequencing Buffer

extension IPTargetMath {
  /// Distance, in meters, that the position lies past the perpendicular through the IP, measured
  /// along the IP→target run-in course. Negative when the position is short of the IP. `nil` when
  /// the position coincides with the IP (no meaningful along-track projection).
  private var signedAlongTrackDistanceM: Double? {
    let IPToTargetDirection = Coordinate.vector(
      from: target.IPCoordinate,
      to: target.coordinate
    )
    let IPToPositionVector = Coordinate.vector(
      from: target.IPCoordinate,
      to: coordinate
    )

    guard IPToTargetDirection.magnitude > 0, IPToPositionVector.magnitude > 0 else { return nil }

    let cosineOfAngle = IPToPositionVector.normalized.dot(IPToTargetDirection.normalized)
    let distanceFromIPM = target.IPCoordinate.distance(to: coordinate).converted(to: .meters).value

    return distanceFromIPM * cosineOfAngle
  }

  /// Absolute angle between the current ground track and the IP→target run-in course, both in true
  /// reference, clamped to `[0°, 180°]`.
  private var trackToRunInAngle: Measurement<UnitAngle> {
    let runInCourse = target.IPCoordinate.bearing(to: target.coordinate)
    let differenceDeg = (course.toTrue(declination: declination) - runInCourse)
      .absoluteValue
      .normalized
      .degrees
    let clampedDeg = min(max(differenceDeg, 0), 180)
    return .init(value: clampedDeg, unit: .degrees)
  }

  /// The level-turn radius, in meters, at the planned target ground speed and the run-in bank
  /// angle.
  private var turnRadiusM: Double {
    let groundSpeedMS = target.targetGroundSpeedMeasurement
      .converted(to: .metersPerSecond)
      .value
    let bankTangent = tan(Self.runInBankAngle.converted(to: .radians).value)
    return (groundSpeedMS * groundSpeedMS) / (Self.gravityMSS * bankTangent)
  }

  /// Required along-track distance, in meters, past the perpendicular before the run-in may
  /// sequence. Grows linearly with the track/run-in angle up to the turn radius; `nil` once the
  /// angle reaches the cutoff (the aircraft is orbiting or reversing course, never sequence).
  private var bufferM: Double? {
    let thetaDeg = trackToRunInAngle.converted(to: .degrees).value
    let cutoffDeg = Self.sequenceCutoffAngle.converted(to: .degrees).value
    guard thetaDeg < cutoffDeg else { return nil }
    return turnRadiusM * (thetaDeg / cutoffDeg)
  }
}
