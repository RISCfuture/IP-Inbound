import Foundation
import Testing

@testable import IP_Inbound

@Suite("FromToMath")
struct FromToMathTests {
  private let SF = Coordinate(latitude: 37.7749, longitude: -122.4194)
  private let LA = Coordinate(latitude: 34.0522, longitude: -118.2437)

  @Test("bearing, calculates correctly")
  func testFromToMathBearing() throws {
    let fromTo = FromToMath(
      from: SF,
      to: LA,
      speed: .init(value: 120, unit: .knots),
      track: .init(angle: 150, reference: .true),
      targetSpeed: .init(value: 120, unit: .knots),
      timeOnTarget: .now.addingTimeInterval(60 * 60),
      declination: .init(value: 13, unit: .degrees)
    )

    // Test bearing calculation (value is approximate)
    #expect(fromTo.bearing.degrees.isApproximatelyEqual(to: 136.5, relativeTolerance: 0.1))
  }

  @Test("distance, calculates correctly")
  func testFromToMathDistance() throws {
    let fromTo = FromToMath(
      from: SF,
      to: LA,
      speed: .init(value: 120, unit: .knots),
      track: .init(angle: 0, reference: .true),
      targetSpeed: .init(value: 120, unit: .knots),
      timeOnTarget: .now.addingTimeInterval(60 * 60),
      declination: .init(value: 0, unit: .degrees)
    )

    // Test distance calculation (should be about 60NM)
    #expect(
      fromTo.distance.converted(to: .kilometers).value.isApproximatelyEqual(
        to: 559.12,
        relativeTolerance: 0.01
      )
    )
  }

  @Test("timeToGo, straight line, calculates correctly")
  func testFromToMathTimeToGoStraightLine() throws {
    let from = Coordinate(latitude: 37.0, longitude: -122.0)
    let to = Coordinate(latitude: 38.0, longitude: -122.0)

    // Speed = 120 knots, distance = ~60NM, so time should be 0.5 hours or 30 minutes
    let fromTo = FromToMath(
      from: from,
      to: to,
      speed: .init(value: 120, unit: .knots),
      track: .init(angle: 0, reference: .true),  // Track aligned with bearing
      targetSpeed: .init(value: 120, unit: .knots),
      timeOnTarget: .now.addingTimeInterval(60 * 60),
      declination: .init(value: 0, unit: .degrees)
    )

    #expect(
      fromTo.timeToGo.converted(to: .minutes).value.isApproximatelyEqual(
        to: 30,
        relativeTolerance: 0.01
      )
    )
  }

  @Test("timeToGo, with turn, calculates correctly")
  func testFromToMathTimeToGoWithTurn() throws {
    // Create test coordinates
    let from = Coordinate(latitude: 37.0, longitude: -122.0)
    let to = Coordinate(latitude: 38.0, longitude: -122.0)

    // Speed = 120 knots, distance = ~60NM, so straight line time would be 30 minutes
    // But we're heading 90 degrees off course, so need to turn
    let fromTo = FromToMath(
      from: from,
      to: to,
      speed: .init(value: 120, unit: .knots),
      track: .init(angle: 90, reference: .true),  // Track is 90 degrees off bearing to target
      targetSpeed: .init(value: 120, unit: .knots),
      timeOnTarget: .now.addingTimeInterval(60 * 60),
      declination: .init(value: 0, unit: .degrees)
    )

    // Test timeToGo calculation - 30 min + ~0.2 min to turn 90°
    #expect(
      fromTo.timeToGo.converted(to: .minutes).value.isApproximatelyEqual(
        to: 30.19,
        relativeTolerance: 0.01
      )
    )
  }

  @Test("deltaTOT, calculates correctly")
  func testFromToMathTOTDelta() throws {
    let from = Coordinate(latitude: 37.0, longitude: -122.0)
    let to = Coordinate(latitude: 38.0, longitude: -122.0)

    // Distance is ~60NM, speed is 120 knots, so timeToGo is 0.5 hours
    // TOT is 1 hour away, so we should be 0.5 hours (30 minutes) early
    let fromTo = FromToMath(
      from: from,
      to: to,
      speed: .init(value: 120, unit: .knots),
      track: .init(angle: 0, reference: .true),
      targetSpeed: .init(value: 120, unit: .knots),
      timeOnTarget: .now.addingTimeInterval(60 * 60),  // 1 hour from now
      declination: .init(value: 0, unit: .degrees)
    )

    // Test deltaTOT calculation - should be negative (early)
    #expect(fromTo.deltaTOT.isApproximatelyEqual(to: -30 * 60, relativeTolerance: 0.01))
    #expect(fromTo.isEarly)
    #expect(!fromTo.isLate)
  }

  @Test("requiredGroundSpeed, calculates straight-line speed to make TOT")
  func testFromToMathRequiredGroundSpeed() throws {
    // SF→LA is ~559.12 km. With a TOT one hour out, the straight-line ground
    // speed required is 559.12 km/h ≈ 301.9 knots, independent of current speed.
    let fromTo = FromToMath(
      from: SF,
      to: LA,
      speed: .init(value: 120, unit: .knots),
      track: .init(angle: 0, reference: .true),
      targetSpeed: .init(value: 120, unit: .knots),
      timeOnTarget: .now.addingTimeInterval(60 * 60),
      declination: .init(value: 0, unit: .degrees)
    )

    let requiredGroundSpeed = try #require(fromTo.requiredGroundSpeed)
    #expect(
      requiredGroundSpeed.converted(to: .knots).value.isApproximatelyEqual(
        to: 301.9,
        relativeTolerance: 0.01
      )
    )
  }

  @Test("requiredGroundSpeed, returns nil once TOT has passed")
  func testFromToMathRequiredGroundSpeedAfterTOT() throws {
    let fromTo = FromToMath(
      from: SF,
      to: LA,
      speed: .init(value: 120, unit: .knots),
      track: .init(angle: 0, reference: .true),
      targetSpeed: .init(value: 120, unit: .knots),
      timeOnTarget: .now.addingTimeInterval(-60),  // TOT was a minute ago
      declination: .init(value: 0, unit: .degrees)
    )

    #expect(fromTo.requiredGroundSpeed == nil)
  }

  @Test("turnTime, 90 degree turn, calculates correctly")
  func testTurnTime90Degrees() throws {
    let speed = Measurement(value: 120, unit: UnitSpeed.knots)
    let fromHeading = Bearing(angle: 0, reference: .magnetic)
    let toHeading = Bearing(angle: 90, reference: .magnetic)

    let turnTime = FromToMath.turnTime(
      fromHeading: fromHeading,
      toHeading: toHeading,
      speed: speed
    )

    // For a 90° turn at 120 knots with 45° bank:
    // Speed = 120 knots ≈ 61.73 m/s
    // Turn rate = g * tan(45°) / v = 9.80665 / 61.73 ≈ 0.1588 rad/s
    // Turn time = (π/2) / 0.1588 ≈ 9.89 seconds
    #expect(
      turnTime.converted(to: .seconds).value.isApproximatelyEqual(
        to: 9.89,
        relativeTolerance: 0.02
      )
    )
  }

  @Test("turnTime, 180 degree turn, calculates correctly")
  func testTurnTime180Degrees() throws {
    let speed = Measurement(value: 120, unit: UnitSpeed.knots)
    let fromHeading = Bearing(angle: 0, reference: .magnetic)
    let toHeading = Bearing(angle: 180, reference: .magnetic)

    let turnTime = FromToMath.turnTime(
      fromHeading: fromHeading,
      toHeading: toHeading,
      speed: speed
    )

    // For a 180° turn, should be exactly 2x the 90° turn time
    #expect(
      turnTime.converted(to: .seconds).value.isApproximatelyEqual(
        to: 19.78,
        relativeTolerance: 0.02
      )
    )
  }

  @Test("turnTime, small turn, returns zero")
  func testTurnTimeSmallTurn() throws {
    let speed = Measurement(value: 120, unit: UnitSpeed.knots)
    let fromHeading = Bearing(angle: 0, reference: .magnetic)
    let toHeading = Bearing(angle: 5, reference: .magnetic)  // 5° is less than 10° threshold

    let turnTime = FromToMath.turnTime(
      fromHeading: fromHeading,
      toHeading: toHeading,
      speed: speed
    )

    // Small turns should return 0
    #expect(turnTime.converted(to: .seconds).value == 0)
  }

  @Test("timeToGo, 90 degree turn, accounts for forward progress during turn")
  func testTimeToGo90DegreeTurnPhysics() throws {
    // Set up a scenario where we can verify the physics:
    // - Aircraft heading due east (90°)
    // - Target is due north (0°), 10,000 meters away
    // - Need to turn 90° to point at target
    // - Speed: 120 knots

    let from = Coordinate(latitude: 37.0, longitude: -122.0)
    // Target is approximately 10km north (about 0.09 degrees latitude at this latitude)
    let to = Coordinate(latitude: 37.09, longitude: -122.0)

    let fromTo = FromToMath(
      from: from,
      to: to,
      speed: .init(value: 120, unit: .knots),
      track: .init(angle: 90, reference: .true),  // Heading east
      targetSpeed: .init(value: 120, unit: .knots),
      timeOnTarget: .now.addingTimeInterval(60 * 60),
      declination: .init(value: 0, unit: .degrees)
    )

    // Physics calculation:
    // Speed = 120 knots ≈ 61.73 m/s
    // Turn radius = v²/(g*tan(45°)) = 61.73² / 9.80665 ≈ 388.8 m
    // Turn time for 90° ≈ 9.89 seconds
    // Chord length = 2 * r * sin(45°) = 2 * 388.8 * 0.7071 ≈ 549.7 m
    // Distance to target ≈ 10,000 m
    // Remaining distance = 10,000 - 549.7 = 9,450.3 m
    // Time for remaining = 9,450.3 / 61.73 ≈ 153.1 seconds
    // Total time = 9.89 + 153.1 = 163 seconds ≈ 2.72 minutes

    let timeToGoSeconds = fromTo.timeToGo.converted(to: .seconds).value

    // Verify that turn time is being used correctly:
    // Total time should be > straight line time (due to turn)
    let straightLineTime = fromTo.distance / fromTo.speed
    #expect(timeToGoSeconds > straightLineTime.converted(to: .seconds).value)

    // Time should be approximately 163 seconds (2.72 minutes)
    #expect(
      timeToGoSeconds.isApproximatelyEqual(
        to: 163,
        relativeTolerance: 0.05
      )
    )
  }

  @Test("turnAnticipationDistance, 90 degree turn, calculates correctly")
  func testTurnAnticipationDistance() throws {
    let speed = Measurement(value: 120, unit: UnitSpeed.knots)
    let fromHeading = Bearing(angle: 0, reference: .magnetic)
    let toHeading = Bearing(angle: 90, reference: .magnetic)

    let anticipationDistance = FromToMath.turnAnticipationDistance(
      fromHeading: fromHeading,
      toHeading: toHeading,
      speed: speed
    )

    // Turn anticipation is typically half the turn time worth of distance
    // Turn time ≈ 9.89 seconds, speed = 61.73 m/s
    // Anticipation = 0.5 * 9.89 * 61.73 ≈ 305 meters ≈ 0.165 NM
    #expect(
      anticipationDistance.converted(to: .nauticalMiles).value.isApproximatelyEqual(
        to: 0.165,
        relativeTolerance: 0.05
      )
    )
  }
}
