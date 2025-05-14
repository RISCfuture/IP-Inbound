import Foundation
@testable import IP_Inbound
import Testing

@Suite("IPTargetMath Tests")
struct IPTargetMathTests {
    let target = Coordinate(latitude: 36.772367, longitude: -115.453840)
    let preIP = Coordinate(latitude: 36.876930, longitude: -115.481479)
    let postIP = Coordinate(latitude: 36.8078222222, longitude: -115.4840472222)

    @Test("isPastIP, is past, returns true")
    func testIPTargetMathIsPastIPWhenPast() throws {
        let target = Target(name: "Test Target", coordinate: target)
        target.offsetBearing = 359
        target.offsetDistance = 4.8

        let ipTargetMath = IPTargetMath(
            coordinate: postIP,
            speed: Measurement(value: 500, unit: .knots),
            course: Bearing(angle: 180, reference: .true),
            target: target
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
            target: target
        )

        #expect(!ipTargetMath.isPastIP)
    }

    @Test("IP_ETA, calculates correctly")
    func testIPTargetMathIPETA() throws {
        let target = Target(name: "Test Target", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        target.offsetBearingIsTrue = true
        target.offsetBearing = 180
        target.offsetDistance = 30
        target.timeOnTarget = .now.addingTimeInterval(60 * 60) // 1 hour from now

        // Position is 60NM from IP, speed is 120 knots, so ETA should be 30 minutes
        let position = Coordinate(latitude: 37.0, longitude: -122.0) // 60NM south of target, 30NM south of IP
        let ipTargetMath = IPTargetMath(
            coordinate: position,
            speed: .init(value: 120, unit: .knots),
            course: .init(angle: 0, reference: .true),
            target: target
        )

        // 30NM to IP at 120 kts = 15 min
        let ETA = try #require(ipTargetMath.IP_ETA)
        #expect(ETA.timeIntervalSinceNow.isApproximatelyEqual(to: 15 * 60, relativeTolerance: 0.01))
    }

    @Test("IPDeltaTime, calculates correctly")
    func testIPTargetMathDeltaTimes() throws {
        let target = Target(name: "Test Target", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        target.offsetBearingIsTrue = true
        target.offsetBearing = 180
        target.offsetDistance = 30
        target.timeOnTarget = .now.addingTimeInterval(60 * 60) // 1 hour from now

        let position = Coordinate(latitude: 37.0, longitude: -122.0) // 60NM south of target, 30NM south of IP
        let ipTargetMath = IPTargetMath(
            coordinate: position,
            speed: .init(value: 120, unit: .knots),
            course: .init(angle: 0, reference: .true),
            target: target
        )

        // 30NM to IP at 120 kts = 15 min; we are 30 min early to IP (45 to target)
        let deltaTime = try #require(ipTargetMath.IPDeltaTime)
        #expect(deltaTime.isApproximatelyEqual(to: -30 * 60, relativeTolerance: 0.01))
    }

    @Test("crossTrackDistance, calculates correctly")
    func testIPTargetMathCrossTrackDistance() throws {
        // Set up a target
        let target = Target(name: "Test Target", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        target.offsetBearing = 90 // IP is due east of the target
        target.offsetBearingIsTrue = true
        target.offsetDistance = 4

        // Position is 60NM south of target and approaching target from the west
        let southOfTarget = IPTargetMath(
            coordinate: .init(latitude: 37.0, longitude: -123.0),
            speed: .init(value: 120, unit: .knots),
            course: .init(angle: 270, reference: .true),
            target: target
        )

        // Cross track distance should be close to 1NM
        // since we are
        #expect(southOfTarget.crossTrackDistance.converted(to: .nauticalMiles).value.isApproximatelyEqual(to: 60, relativeTolerance: 0.01))

        // Position is 60NM north of target and approaching target from the west
        let northOfTarget = IPTargetMath(
            coordinate: .init(latitude: 39.0, longitude: -123.0),
            speed: .init(value: 120, unit: .knots),
            course: .init(angle: 270, reference: .true),
            target: target
        )

        // Cross track distance should be close to 1NM
        // since we are
        #expect(northOfTarget.crossTrackDistance.converted(to: .nauticalMiles).value.isApproximatelyEqual(to: -60, relativeTolerance: 0.01))
    }
}
