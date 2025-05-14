import CoreLocation
@testable import IP_Inbound
import Testing

@Suite("Target")
struct TargetTests {
    @Test("offsetBearing, normalizes correctly")
    func testTargetNormalizesBearing() throws {
        let target = Target(name: "Test", coordinate: .zero)
        target.offsetBearing = 370
        #expect(target.offsetBearing == 10)

        target.offsetBearing = -30
        #expect(target.offsetBearing == 330)
    }

    @Test("IPCoordinate, calculates correctly")
    func testTargetIPCoordinate() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        target.offsetBearing = 180
        target.offsetDistance = 4
        target.offsetBearingIsTrue = true

        let ipCoord = target.IPCoordinate
        #expect(ipCoord.latitudeDeg == 37.933378255433546)
        #expect(ipCoord.longitudeDeg == -122)
    }

    @Test("setOffset, updates distance")
    func testTargetOffsetTypeChangeDistanceToTime() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        target.targetGroundSpeed = 120 // 120 knots

        target.setOffset(distance: .init(value: 10, unit: .nauticalMiles))
        #expect(target.offsetTime.isApproximatelyEqual(to: 5, relativeTolerance: 0.01))
        #expect(target.offsetDistance == 10)
    }

    @Test("setOffset, updates time")
    func testTargetOffsetTypeChangeTimeToDistance() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        target.targetGroundSpeed = 120 // 120 knots

        target.setOffset(time: .init(value: 5, unit: .minutes))
        #expect(target.offsetDistance.isApproximatelyEqual(to: 10, relativeTolerance: 0.01))
        #expect(target.offsetTime == 5)
    }

    @Test("desiredTrack, calculates correctly")
    func testTargetDesiredTracks() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        target.offsetBearing = 45
        target.offsetBearingIsTrue = false // magnetic
        target.declination = 15 // 15 degrees east

        // Desired track should be reciprocal of offset bearing (225 magnetic)
        #expect(target.desiredTrack.degrees == 225)
        #expect(target.desiredTrack.reference == .magnetic)

        // Magnetic to true conversion: 225 magnetic = 240 true with 15° east declination
        #expect(target.desiredTrackTrue.degrees == 240)
        #expect(target.desiredTrackTrue.reference == .true)

        // Change to true bearing
        target.offsetBearingIsTrue = true
        target.offsetBearing = 45

        // Desired track should be reciprocal of offset bearing (225 true)
        #expect(abs(target.desiredTrack.degrees - 225) < 0.1)
        #expect(target.desiredTrack.reference == .true)

        // True to magnetic conversion: 225 true = 210 magnetic with 15° east declination
        #expect(abs(target.desiredTrackMagnetic.degrees - 210) < 0.1)
        #expect(target.desiredTrackMagnetic.reference == .magnetic)
    }

    @Test("desiredTimeOverIP, calculates correctly")
    func testTargetDesiredTimeOverIP() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))

        // Configure target
        target.targetGroundSpeed = 120 // 120 knots
        target.offsetDistance = 10 // 10 NM

        // At 120 knots, 10 NM takes 5 minutes
        // Set TOT to 30 minutes from now
        let tot = Date.now.addingTimeInterval(30 * 60)
        target.timeOnTarget = tot

        // Desired time over IP should be 5 minutes before TOT
        let desiredTimeOverIP = try #require(target.desiredTimeOverIP),
            expectedTime = tot.addingTimeInterval(-5 * 60)
        #expect((desiredTimeOverIP.timeIntervalSince1970 - expectedTime.timeIntervalSince1970).magnitude < 1)
    }

    @Test("maxAllowableTimeOverIP, calculates correctly")
    func testTargetMaxAllowableTimeOverIP() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))

        // Configure target
        target.targetGroundSpeed = 100 // 100 knots
        target.offsetDistance = 10 // 10 NM

        // Set TOT to 30 minutes from now
        let tot = Date.now.addingTimeInterval(30 * 60)
        target.timeOnTarget = tot

        // At 100 knots, 10 NM takes 6 minutes
        // With allowable speed variance of 10%, max speed is 110 knots
        // At 110 knots, 10 NM takes about 5.45 minutes

        let maxAllowableTimeOverIP = try #require(target.maxAllowableTimeOverIP)

        // Should be about 5.45 minutes before TOT
        let expectedTime = tot.addingTimeInterval(-5.45 * 60)
        #expect(abs(maxAllowableTimeOverIP.timeIntervalSince1970 - expectedTime.timeIntervalSince1970) < 5)
    }

    @Test("calculateDeclination, calculates correctly")
    func testTargetCalculateDeclination() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        target.calculateDeclination()

        #expect(target.declination.isApproximatelyEqual(to: 12.919, relativeTolerance: 0.01))
    }
}
