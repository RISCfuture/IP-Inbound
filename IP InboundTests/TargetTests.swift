import CoreLocation
import Testing

@testable import IP_Inbound

@Suite("Target")
struct TargetTests {
  @Test("offsetBearing, normalizes correctly")
  func targetNormalizesBearing() {
    let target = Target(name: "Test", coordinate: .zero)
    target.offsetBearing = 370
    #expect(target.offsetBearing == 10)

    target.offsetBearing = -30
    #expect(target.offsetBearing == 330)
  }

  @Test("IPCoordinate, calculates correctly")
  func targetIPCoordinate() {
    let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
    target.offsetBearing = 180
    target.offsetDistance = 4
    target.offsetBearingIsTrue = true

    let ipCoord = target.IPCoordinate
    #expect(ipCoord.latitudeDeg == 37.933378255433546)
    #expect(ipCoord.longitudeDeg == -122)
  }

  @Test("setOffset, rounds distance to a whole unit and derives time from it")
  func targetOffsetTypeChangeDistanceToTime() {
    let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
    target.targetGroundSpeed = 120  // 120 knots

    target.setOffset(distance: .init(value: 9.6, unit: .nauticalMiles))
    // Distance rounds to a whole 10 NM, and the time is re-derived from that
    // rounded distance (10 NM at 120 kt = 5 min) — not from the 9.6 NM input.
    #expect(target.offsetDistance == 10)
    #expect(target.offsetTime.isApproximatelyEqual(to: 5, relativeTolerance: 0.01))
  }

  @Test("setOffset, rounds time to a whole minute and derives distance from it")
  func targetOffsetTypeChangeTimeToDistance() {
    let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
    target.targetGroundSpeed = 120  // 120 knots

    target.setOffset(time: .init(value: 3.7, unit: .minutes))
    // Time rounds to a whole 4 min, and the distance is re-derived from that
    // rounded time (4 min at 120 kt = 8 NM) — so timing matches the displayed
    // whole-minute value exactly.
    #expect(target.offsetTime == 4)
    #expect(target.offsetDistance.isApproximatelyEqual(to: 8, relativeTolerance: 0.01))
  }

  @Test("desiredTrack, calculates correctly")
  func targetDesiredTracks() {
    let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
    target.offsetBearing = 45
    target.offsetBearingIsTrue = false  // magnetic
    target.declination = 15  // 15 degrees east

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
  func targetDesiredTimeOverIP() throws {
    let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))

    // Configure target
    target.targetGroundSpeed = 120  // 120 knots
    target.offsetDistance = 10  // 10 NM

    // At 120 knots, 10 NM takes 5 minutes
    // Set TOT to 30 minutes from now
    let tot = Date.now.addingTimeInterval(30 * 60)
    target.timeOnTarget = tot

    // Desired time over IP should be 5 minutes before TOT
    let desiredTimeOverIP = try #require(target.desiredTimeOverIP)
    let expectedTime = tot.addingTimeInterval(-5 * 60)
    #expect(
      (desiredTimeOverIP.timeIntervalSince1970 - expectedTime.timeIntervalSince1970).magnitude < 1
    )
  }

  @Test("maxAllowableTimeOverIP, calculates correctly")
  func targetMaxAllowableTimeOverIP() throws {
    let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))

    // Configure target
    target.targetGroundSpeed = 100  // 100 knots
    target.offsetDistance = 10  // 10 NM

    // Set TOT to 30 minutes from now
    let tot = Date.now.addingTimeInterval(30 * 60)
    target.timeOnTarget = tot

    // At 100 knots, 10 NM takes 6 minutes
    // With allowable speed variance of 10%, max speed is 110 knots
    // At 110 knots, 10 NM takes about 5.45 minutes

    let maxAllowableTimeOverIP = try #require(target.maxAllowableTimeOverIP)

    // Should be about 5.45 minutes before TOT
    let expectedTime = tot.addingTimeInterval(-5.45 * 60)
    #expect(
      abs(maxAllowableTimeOverIP.timeIntervalSince1970 - expectedTime.timeIntervalSince1970) < 5
    )
  }

  @Test("calculateDeclination, calculates correctly")
  func targetCalculateDeclination() {
    let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
    target.calculateDeclination()

    #expect(target.declination.isApproximatelyEqual(to: 12.919, relativeTolerance: 0.01))
  }
}
