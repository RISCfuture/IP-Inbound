import Foundation
import Testing

@testable import IP_Inbound

@Suite("IPTargetMath Tests")
struct IPTargetMathTests {
  let target = Coordinate(latitude: 36.772367, longitude: -115.453840)
  let preIP = Coordinate(latitude: 36.876930, longitude: -115.481479)
  let postIP = Coordinate(latitude: 36.8078222222, longitude: -115.4840472222)
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  @Test("isPastIP, is past, returns true")
  func testIPTargetMathIsPastIPWhenPast() throws {
    let target = Target(name: "Test Target", coordinate: target)
    target.offsetBearing = 359
    target.offsetDistance = 4.8

    let ipTargetMath = IPTargetMath(
      coordinate: postIP,
      speed: Measurement(value: 500, unit: .knots),
      course: Bearing(angle: 180, reference: .true),
      target: target,
      now: now
    )

    #expect(ipTargetMath.isPastIP)
  }

  @Test("isPastIP, is not past, returns false")
  func testIPTargetMathIsPastIPWhenNotPast() throws {
    let target = Target(name: "Test Target", coordinate: target)
    target.offsetBearing = 359
    target.offsetDistance = 4.8

    let ipTargetMath = IPTargetMath(
      coordinate: preIP,
      speed: Measurement(value: 500, unit: .knots),
      course: Bearing(angle: 180, reference: .true),
      target: target,
      now: now
    )

    #expect(!ipTargetMath.isPastIP)
  }

  @Test("IP_ETA, calculates correctly")
  func testIPTargetMathIPETA() throws {
    let target = Target(
      name: "Test Target",
      coordinate: Coordinate(latitude: 38.0, longitude: -122.0)
    )
    target.offsetBearingIsTrue = true
    target.offsetBearing = 180
    target.offsetDistance = 30
    target.timeOnTarget = now.addingTimeInterval(60 * 60)  // 1 hour from now

    // Position is 60NM from IP, speed is 120 knots, so ETA should be 30 minutes
    let position = Coordinate(latitude: 37.0, longitude: -122.0)  // 60NM south of target, 30NM south of IP
    let ipTargetMath = IPTargetMath(
      coordinate: position,
      speed: .init(value: 120, unit: .knots),
      course: .init(angle: 0, reference: .true),
      target: target,
      now: now
    )

    // 30NM to IP at 120 kts = 15 min
    let ETA = try #require(ipTargetMath.IP_ETA)
    #expect(ETA.timeIntervalSince(now).isApproximatelyEqual(to: 15 * 60, relativeTolerance: 0.01))
  }

  @Test("IPDeltaTime, calculates correctly")
  func testIPTargetMathDeltaTimes() throws {
    let target = Target(
      name: "Test Target",
      coordinate: Coordinate(latitude: 38.0, longitude: -122.0)
    )
    target.offsetBearingIsTrue = true
    target.offsetBearing = 180
    target.offsetDistance = 30
    target.timeOnTarget = now.addingTimeInterval(60 * 60)  // 1 hour from now

    let position = Coordinate(latitude: 37.0, longitude: -122.0)  // 60NM south of target, 30NM south of IP
    let ipTargetMath = IPTargetMath(
      coordinate: position,
      speed: .init(value: 120, unit: .knots),
      course: .init(angle: 0, reference: .true),
      target: target,
      now: now
    )

    // 30NM to IP at 120 kts = 15 min; we are 30 min early to IP (45 to target)
    let deltaTime = try #require(ipTargetMath.IPDeltaTime)
    #expect(deltaTime.isApproximatelyEqual(to: -30 * 60, relativeTolerance: 0.01))
  }

  // MARK: - IP Sequencing Buffer

  /// Builds a target whose run-in course (IP→target) points due north (true) with the IP roughly
  /// ten nautical miles south of the target, at the given planned ground speed.
  private func runInTarget(groundSpeedKts: Double) -> Target {
    let target = Target(
      name: "Buffer Target",
      coordinate: Coordinate(latitude: 36.0, longitude: -115.0)
    )
    target.offsetBearingIsTrue = true
    target.offsetBearing = 180
    target.offsetDistance = 10
    target.targetGroundSpeed = groundSpeedKts
    return target
  }

  @Test("isPastIP, track straight at target, sequences at the perpendicular")
  func testIsPastIPNoBufferWhenOnCourse() throws {
    let target = runInTarget(groundSpeedKts: 500)
    let IP = target.IPCoordinate

    // Just short of the IP must not sequence.
    let shortOfIP = IP.offsetBy(
      bearing: .init(value: 180, unit: .degrees),
      distance: .init(value: 100, unit: .meters)
    )
    let beforeIP = IPTargetMath(
      coordinate: shortOfIP,
      speed: .init(value: 500, unit: .knots),
      course: .init(angle: 0, reference: .true),
      target: target,
      now: now
    )
    #expect(!beforeIP.isPastIP)

    // Fifty meters past the perpendicular, on course, must sequence (buffer is zero at θ≈0).
    let justPastIP = IP.offsetBy(
      bearing: .init(value: 0, unit: .degrees),
      distance: .init(value: 50, unit: .meters)
    )
    let afterIP = IPTargetMath(
      coordinate: justPastIP,
      speed: .init(value: 500, unit: .knots),
      course: .init(angle: 0, reference: .true),
      target: target,
      now: now
    )
    #expect(afterIP.isPastIP)
  }

  @Test("isPastIP, track 90° off run-in, never sequences")
  func testIsPastIPNeverSequencesAtNinetyDegrees() throws {
    let target = runInTarget(groundSpeedKts: 500)
    let IP = target.IPCoordinate

    // Five kilometers past the IP — well past the perpendicular — but the ground track is
    // perpendicular to the run-in course, so the run-in must not sequence.
    let wellPastIP = IP.offsetBy(
      bearing: .init(value: 0, unit: .degrees),
      distance: .init(value: 5000, unit: .meters)
    )
    let crossing = IPTargetMath(
      coordinate: wellPastIP,
      speed: .init(value: 500, unit: .knots),
      course: .init(angle: 90, reference: .true),
      target: target,
      now: now
    )
    #expect(!crossing.isPastIP)
  }

  @Test("isPastIP, track 45° off run-in, sequences only after ~r/2")
  func testIsPastIPHalfRadiusBufferAtFortyFiveDegrees() throws {
    let groundSpeedKts = 500.0
    let target = runInTarget(groundSpeedKts: groundSpeedKts)
    let IP = target.IPCoordinate

    let gravityMSS = 9.80665
    let groundSpeedMS = Measurement(value: groundSpeedKts, unit: UnitSpeed.knots)
      .converted(to: .metersPerSecond)
      .value
    let turnRadiusM = (groundSpeedMS * groundSpeedMS) / (gravityMSS * tan(.pi / 4))
    let halfRadiusM = turnRadiusM / 2

    // Just past the perpendicular but short of the r/2 buffer: must not sequence.
    let shortOfBuffer = IP.offsetBy(
      bearing: .init(value: 0, unit: .degrees),
      distance: .init(value: halfRadiusM - 400, unit: .meters)
    )
    let beforeBuffer = IPTargetMath(
      coordinate: shortOfBuffer,
      speed: .init(value: 500, unit: .knots),
      course: .init(angle: 45, reference: .true),
      target: target,
      now: now
    )
    #expect(!beforeBuffer.isPastIP)

    // Past the r/2 buffer: must sequence.
    let pastBuffer = IP.offsetBy(
      bearing: .init(value: 0, unit: .degrees),
      distance: .init(value: halfRadiusM + 400, unit: .meters)
    )
    let afterBuffer = IPTargetMath(
      coordinate: pastBuffer,
      speed: .init(value: 500, unit: .knots),
      course: .init(angle: 45, reference: .true),
      target: target,
      now: now
    )
    #expect(afterBuffer.isPastIP)
  }

  @Test("isPastIP, orbiting at the IP with track 135° off, does not sequence")
  func testIsPastIPOrbitDoesNotSequence() throws {
    let target = runInTarget(groundSpeedKts: 500)
    let IP = target.IPCoordinate

    // The aircraft has just re-crossed the perpendicular while orbiting; its ground track is 135°
    // off the run-in course. This must not flip the guidance state.
    let justPastIP = IP.offsetBy(
      bearing: .init(value: 0, unit: .degrees),
      distance: .init(value: 200, unit: .meters)
    )
    let orbiting = IPTargetMath(
      coordinate: justPastIP,
      speed: .init(value: 500, unit: .knots),
      course: .init(angle: 135, reference: .true),
      target: target,
      now: now
    )
    #expect(!orbiting.isPastIP)
  }

  @Test("isPastIP, far off the run-in axis, projects along the true course")
  func testIsPastIPUsesTrueAlongTrackOffAxis() throws {
    let target = runInTarget(groundSpeedKts: 500)
    let IP = target.IPCoordinate

    // Sixty meters short of the IP's perpendicular but well off to the side. The true along-track
    // distance is negative (short of the IP), so an on-course aircraft must not sequence — even
    // though a latitude-dropping vector projection wrongly reads this position as past the IP.
    let shortButFarEast =
      IP
      .offsetBy(
        bearing: .init(value: 180, unit: .degrees),
        distance: .init(value: 60, unit: .meters)
      )
      .offsetBy(
        bearing: .init(value: 90, unit: .degrees),
        distance: .init(value: 39_000, unit: .meters)
      )
    let math = IPTargetMath(
      coordinate: shortButFarEast,
      speed: .init(value: 500, unit: .knots),
      course: .init(angle: 0, reference: .true),
      target: target,
      now: now
    )
    #expect(!math.isPastIP)
  }

  @Test("crossTrackDistance, calculates correctly")
  func testIPTargetMathCrossTrackDistance() throws {
    // Set up a target
    let target = Target(
      name: "Test Target",
      coordinate: Coordinate(latitude: 38.0, longitude: -122.0)
    )
    target.offsetBearing = 90  // IP is due east of the target
    target.offsetBearingIsTrue = true
    target.offsetDistance = 4

    // Position is 60NM south of target and approaching target from the west
    let southOfTarget = IPTargetMath(
      coordinate: .init(latitude: 37.0, longitude: -123.0),
      speed: .init(value: 120, unit: .knots),
      course: .init(angle: 270, reference: .true),
      target: target,
      now: now
    )

    // Cross track distance should be close to 1NM
    // since we are
    #expect(
      southOfTarget.crossTrackDistance.converted(to: .nauticalMiles).value.isApproximatelyEqual(
        to: 60,
        relativeTolerance: 0.01
      )
    )

    // Position is 60NM north of target and approaching target from the west
    let northOfTarget = IPTargetMath(
      coordinate: .init(latitude: 39.0, longitude: -123.0),
      speed: .init(value: 120, unit: .knots),
      course: .init(angle: 270, reference: .true),
      target: target,
      now: now
    )

    // Cross track distance should be close to 1NM
    // since we are
    #expect(
      northOfTarget.crossTrackDistance.converted(to: .nauticalMiles).value.isApproximatelyEqual(
        to: -60,
        relativeTolerance: 0.01
      )
    )
  }
}
