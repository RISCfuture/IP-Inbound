@testable import IP_Inbound
import Testing

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
        #expect(fromTo.distance.converted(to: .kilometers).value.isApproximatelyEqual(to: 559.12, relativeTolerance: 0.01))
    }

    @Test("timeToGo, straight line, calculates correctly")
    func testFromToMathTimeToGoStraightLine() throws {
        let from = Coordinate(latitude: 37.0, longitude: -122.0),
            to = Coordinate(latitude: 38.0, longitude: -122.0)

        // Speed = 120 knots, distance = ~60NM, so time should be 0.5 hours or 30 minutes
        let fromTo = FromToMath(
            from: from,
            to: to,
            speed: .init(value: 120, unit: .knots),
            track: .init(angle: 0, reference: .true), // Track aligned with bearing
            targetSpeed: .init(value: 120, unit: .knots),
            timeOnTarget: .now.addingTimeInterval(60 * 60),
            declination: .init(value: 0, unit: .degrees)
        )

        #expect(fromTo.timeToGo.converted(to: .minutes).value.isApproximatelyEqual(to: 30, relativeTolerance: 0.01))
    }

    @Test("timeToGo, with turn, calculates correctly")
    func testFromToMathTimeToGoWithTurn() throws {
        // Create test coordinates
        let from = Coordinate(latitude: 37.0, longitude: -122.0),
            to = Coordinate(latitude: 38.0, longitude: -122.0)

        // Speed = 120 knots, distance = ~60NM, so straight line time would be 30 minutes
        // But we're heading 90 degrees off course, so need to turn
        let fromTo = FromToMath(
            from: from,
            to: to,
            speed: .init(value: 120, unit: .knots),
            track: .init(angle: 90, reference: .true), // Track is 90 degrees off bearing to target
            targetSpeed: .init(value: 120, unit: .knots),
            timeOnTarget: .now.addingTimeInterval(60 * 60),
            declination: .init(value: 0, unit: .degrees)
        )

        // Test timeToGo calculation - 30 min + ~0.2 min to turn 90°
        #expect(fromTo.timeToGo.converted(to: .minutes).value.isApproximatelyEqual(to: 30.19, relativeTolerance: 0.01))
    }

    @Test("deltaTOT, calculates correctly")
    func testFromToMathTOTDelta() throws {
        let from = Coordinate(latitude: 37.0, longitude: -122.0),
            to = Coordinate(latitude: 38.0, longitude: -122.0)

        // Distance is ~60NM, speed is 120 knots, so timeToGo is 0.5 hours
        // TOT is 1 hour away, so we should be 0.5 hours (30 minutes) early
        let fromTo = FromToMath(
            from: from,
            to: to,
            speed: .init(value: 120, unit: .knots),
            track: .init(angle: 0, reference: .true),
            targetSpeed: .init(value: 120, unit: .knots),
            timeOnTarget: .now.addingTimeInterval(60 * 60), // 1 hour from now
            declination: .init(value: 0, unit: .degrees)
        )

        // Test deltaTOT calculation - should be negative (early)
        #expect(fromTo.deltaTOT.isApproximatelyEqual(to: -30 * 60, relativeTolerance: 0.01))
        #expect(fromTo.isEarly)
        #expect(!fromTo.isLate)
    }
}
