public import CoreLocation
public import Foundation
import MeasurementKit
public import MeasurementKitLocation

/// The run-in geometry a single fix produces against a target: where the aircraft sits relative to
/// the initial point and the target, when it will reach each, and how far it lies off the run-in
/// course. The phone and the watch both solve from this, so their guidance cannot disagree.
public struct IPTargetMath<T: GuidanceTarget> {
  private static var sequenceCutoffAngle: Measurement<UnitAngle> {
    .init(value: 90, unit: .degrees)
  }

  /// Where the aircraft is.
  public var coordinate: Coordinate

  /// The aircraft's ground speed.
  public var speed: Measurement<UnitSpeed>

  /// The aircraft's track over the ground.
  public var course: TrueBearing

  /// The target being run in on.
  public let target: T

  /// The instant the geometry is solved for.
  public let now: Date

  /// Timing toward the IP. Because the destination is the IP, the run-to time reference is the
  /// desired IP-crossing time (`desiredTimeOverIP`) — not the target's time-on-target — so
  /// early/late and required-ground-speed read against when the aircraft should cross the IP.
  public var pposToIP: FromToMath? {
    guard let desiredTimeOverIP = target.desiredTimeOverIP else { return nil }
    return .init(
      from: coordinate,
      to: target.IPCoordinate,
      speed: speed,
      track: course,
      targetSpeed: target.targetGroundSpeedMeasurement,
      timeOnTarget: desiredTimeOverIP,
      declination: declination,
      now: now
    )
  }

  /// Timing straight to the target, referenced to its time-on-target, for the phases that bypass
  /// the IP.
  public var pposToTarget: FromToMath? {
    guard let timeOnTarget = target.timeOnTarget else { return nil }
    return .init(
      from: coordinate,
      to: target.coordinate,
      speed: speed,
      track: course,
      targetSpeed: target.targetGroundSpeedMeasurement,
      timeOnTarget: timeOnTarget,
      declination: declination,
      now: now
    )
  }

  /// Whether the initial point is behind the aircraft, allowing for the buffer a turn onto the
  /// run-in course needs.
  public var isPastIP: Bool {
    guard let signedAlongTrackDistance, let sequencingBuffer else { return false }
    return signedAlongTrackDistance >= sequencingBuffer
  }

  /// When the aircraft will reach the IP at its current speed.
  public var IP_ETA: Date? { pposToIP?.timeOfArrival }

  /// How far the projected IP crossing falls from the time the plan wants it, negative when early.
  public var IPDeltaTime: Measurement<UnitDuration>? {
    guard let IP_ETA, let desiredTimeOverIP = target.desiredTimeOverIP else { return nil }
    return IP_ETA.elapsed(since: desiredTimeOverIP)
  }

  /// How far the position lies off the run-in course line. Positive is **right** of course, the
  /// course-deviation convention, so a positive deviation is corrected by turning left.
  public var crossTrackDistance: Measurement<UnitLength> {
    target.IPToTarget.crossTrackDistance(to: coordinate)
  }

  /// The aircraft's displacement from the run-in course line, as a course deviation indicator reads
  /// it.
  public var courseDeviation: CourseDeviation { .init(crossTrackDistance: crossTrackDistance) }

  /// The earliest the aircraft could reach the target by way of the IP, flying the fastest run-in
  /// speed the guidance will plan to. Later than the time-on-target means the plan cannot be made.
  public var pposToIPToTargetETAAtMaxSpeed: Date? {
    guard target.timeOnTarget != nil else { return nil }

    let maxSpeed = target.maxAllowableGroundSpeed

    // Time from PPOS to IP at max speed (including turn from current heading)
    let distanceToIP = coordinate.distance(to: target.IPCoordinate)
    let turnToIPTime = FromToMath.turnTime(
      fromHeading: course.toMagnetic(variation: declination),
      toHeading: coordinate.initialBearing(to: target.IPCoordinate)
        .toMagnetic(variation: declination),
      speed: maxSpeed
    )
    let straightTimeToIP = distanceToIP / maxSpeed
    let totalTimeToIP = straightTimeToIP + turnToIPTime

    // Time from IP to Target at max speed
    let ipToTargetDistance = target.IPToTarget.length
    let straightTimeIPToTarget = ipToTargetDistance / maxSpeed

    // Calculate turn anticipation at IP
    // The bearing we'll be on when arriving at IP is from PPOS to IP
    let ipBearing = coordinate.initialBearing(to: target.IPCoordinate)
    let turnAtIPTime = FromToMath.turnTime(
      fromHeading: ipBearing.toMagnetic(variation: declination),
      toHeading: target.desiredTrackMagnetic,
      speed: maxSpeed
    )

    // Turn anticipation reduces total time (start turn before IP)
    let turnAnticipation = turnAtIPTime * 0.5

    // Total time = PPOS to IP + IP to Target - turn anticipation
    let totalTime = totalTimeToIP + straightTimeIPToTarget - turnAnticipation

    return now + totalTime
  }

  private var declination: Measurement<UnitAngle> { target.declinationMeasurement }

  /// Solves the run-in geometry from an explicit position, speed and track.
  ///
  /// - Parameters:
  ///   - coordinate: where the aircraft is.
  ///   - speed: its ground speed.
  ///   - course: its track over the ground.
  ///   - target: the target being run in on.
  ///   - now: the instant to solve for.
  public init(
    coordinate: Coordinate,
    speed: Measurement<UnitSpeed>,
    course: TrueBearing,
    target: T,
    now: Date
  ) {
    self.coordinate = coordinate
    self.speed = speed
    self.course = course
    self.target = target
    self.now = now
  }

  /// The guidance geometry for `location`, or `nil` when the fix carries no usable ground speed or
  /// course. Core Location signals either with a negative sentinel, which taken at face value
  /// dead-reckons the run-in backwards or a degree west of north.
  ///
  /// - Parameters:
  ///   - location: the fix to solve from.
  ///   - target: the target being run in on.
  ///   - now: the current time.
  public init?(location: CLLocation, target: T, now: Date) {
    guard let speed = location.groundSpeed, let course = location.courseTrue else { return nil }
    self.init(
      coordinate: location.geoCoordinate,
      speed: speed,
      course: course,
      target: target,
      now: now
    )
  }
}

extension IPTargetMath: Equatable where T: Equatable {}

// MARK: - IP Sequencing Buffer

extension IPTargetMath {
  /// Distance that the position lies past the perpendicular through the IP, measured along the
  /// IP→target run-in course. Negative when the position is short of the IP. `nil` when the position
  /// coincides with the IP (no meaningful along-track projection).
  private var signedAlongTrackDistance: Measurement<UnitLength>? {
    let distanceFromIP = target.IPCoordinate.distance(to: coordinate)
    guard distanceFromIP > .zero else { return nil }

    // Project the IP→position distance onto the IP→target run-in course using the true bearings, so
    // the along-track distance stays correct off-axis and at higher latitudes (a flat-plane vector
    // projection distorts the angle and biases the result).
    let runInCourse = target.IPCoordinate.initialBearing(to: target.coordinate)
    let bearingToPosition = target.IPCoordinate.initialBearing(to: coordinate)
    let offCourseAngle = (bearingToPosition - runInCourse).radians

    return distanceFromIP * cos(offCourseAngle)
  }

  /// Absolute angle between the current ground track and the IP→target run-in course, both true.
  /// A `RelativeBearing` already normalizes into (−180°, 180°], so its magnitude is in [0°, 180°].
  private var trackToRunInAngle: Measurement<UnitAngle> {
    let runInCourse = target.IPCoordinate.initialBearing(to: target.coordinate)
    return (course - runInCourse).magnitude
  }

  /// The level-turn radius at the planned target ground speed and the run-in bank angle.
  private var turnRadius: Measurement<UnitLength> {
    let groundSpeed = target.targetGroundSpeedMeasurement
    let turnAcceleration = Measurement.standardGravity * tan(FromToMath.bankAngle)
    return groundSpeed / turnAcceleration * groundSpeed
  }

  /// Required along-track distance past the perpendicular before the run-in may sequence. Grows
  /// linearly with the track/run-in angle up to the turn radius; `nil` once the angle reaches the
  /// cutoff (the aircraft is orbiting or reversing course, never sequence).
  private var sequencingBuffer: Measurement<UnitLength>? {
    guard trackToRunInAngle < Self.sequenceCutoffAngle else { return nil }
    return turnRadius * (trackToRunInAngle / Self.sequenceCutoffAngle)
  }
}
