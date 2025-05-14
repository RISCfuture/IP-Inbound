@testable import IP_Inbound
import CoreLocation
import Testing

@Suite("Target Tests")
struct TargetTests {
    
    @Test("Target initializes with correct defaults")
    func testTargetInitialization() throws {
        let coordinate = Coordinate(latitude: 38.0, longitude: -122.0)
        let target = Target(name: "Test Target", coordinate: coordinate)
        
        #expect(target.name == "Test Target")
        #expect(abs(target.latitude - 38.0) < 0.0001)
        #expect(abs(target.longitude - (-122.0)) < 0.0001)
        #expect(!target.isConfigured)
    }
    
    @Test("Target normalizes offset bearing correctly")
    func testTargetNormalizesBearing() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 0, longitude: 0))
        
        target.offsetBearing = 370
        #expect(abs(target.offsetBearing - 10) < 0.0001)
        
        target.offsetBearing = -30
        #expect(abs(target.offsetBearing - 330) < 0.0001)
    }
    
    @Test("Target calculates IP coordinate correctly")
    func testTargetIPCoordinate() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        
        // Set offset to 4NM due south (bearing 180)
        target.offsetBearing = 180
        target.offsetDistance = 4
        target.offsetBearingIsTrue = true // use true bearing
        
        // IP should be approximately 4NM south of target
        let ipCoord = target.IPCoordinate
        
        // IP should be south of target
        #expect(ipCoord.latitudeDeg < target.latitude)
        #expect(abs(ipCoord.longitudeDeg - target.longitude) < 0.001)
        
        // Distance should be close to 4NM
        let distance = ipCoord.distance(to: target.coordinate).converted(to: .nauticalMiles).value
        #expect(abs(distance - 4) < 0.1)
    }
    
    @Test("Target handles offset type change correctly - distance to time")
    func testTargetOffsetTypeChangeDistanceToTime() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        
        // Set initial values
        target.targetGroundSpeed = 120 // 120 knots
        target.offsetDistance = 10 // 10 NM
        target.offsetType = .distance
        
        // At 120 knots, 10 NM takes 5 minutes
        #expect(abs(target.offsetTime - 5) < 0.1)
        
        // Change offset type to time
        target.offsetType = .time
        
        // Distance should remain unchanged
        #expect(abs(target.offsetDistance - 10) < 0.1)
        #expect(abs(target.offsetTime - 5) < 0.1)
    }
    
    @Test("Target handles offset type change correctly - time to distance")
    func testTargetOffsetTypeChangeTimeToDistance() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        
        // Set initial values
        target.targetGroundSpeed = 120 // 120 knots
        target.offsetTime = 5 // 5 minutes
        target.offsetType = .time
        
        // At 120 knots for 5 minutes, should go 10 NM
        #expect(abs(target.offsetDistance - 10) < 0.1)
        
        // Change offset type to distance
        target.offsetType = .distance
        
        // Time should remain unchanged
        #expect(abs(target.offsetDistance - 10) < 0.1)
        #expect(abs(target.offsetTime - 5) < 0.1)
    }
    
    @Test("Target updates distance when time changes")
    func testTargetUpdatesDistanceWhenTimeChanges() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        
        // Set initial values
        target.targetGroundSpeed = 120 // 120 knots
        target.offsetType = .time
        target.offsetTime = 5 // 5 minutes
        
        // Distance should be set based on time and speed (10 NM)
        #expect(abs(target.offsetDistance - 10) < 0.1)
        
        // Change time
        target.offsetTime = 10 // 10 minutes
        
        // Distance should update (20 NM)
        #expect(abs(target.offsetDistance - 20) < 0.1)
    }
    
    @Test("Target updates time when distance changes")
    func testTargetUpdatesTimeWhenDistanceChanges() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        
        // Set initial values
        target.targetGroundSpeed = 120 // 120 knots
        target.offsetType = .distance
        target.offsetDistance = 10 // 10 NM
        
        // Time should be set based on distance and speed (5 minutes)
        #expect(abs(target.offsetTime - 5) < 0.1)
        
        // Change distance
        target.offsetDistance = 20 // 20 NM
        
        // Time should update (10 minutes)
        #expect(abs(target.offsetTime - 10) < 0.1)
    }
    
    @Test("Target calculates desired tracks correctly")
    func testTargetDesiredTracks() throws {
        let target = Target(name: "Test", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        
        // Set offset bearing to 45 degrees
        target.offsetBearing = 45
        target.offsetBearingIsTrue = false // magnetic
        target.declination = 15 // 15 degrees east
        
        // Desired track should be reciprocal of offset bearing (225 magnetic)
        #expect(abs(target.desiredTrack.degrees - 225) < 0.1)
        #expect(target.desiredTrack.reference == .magnetic)
        
        // Magnetic to true conversion: 225 magnetic = 240 true with 15° east declination
        #expect(abs(target.desiredTrackTrue.degrees - 240) < 0.1)
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
    
    @Test("Target calculates desired time over IP correctly")
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
        guard let desiredTimeOverIP = target.desiredTimeOverIP else {
            throw ExpectationFailedError("desiredTimeOverIP should not be nil")
        }
        
        let expectedTime = tot.addingTimeInterval(-5 * 60)
        #expect(abs(desiredTimeOverIP.timeIntervalSince1970 - expectedTime.timeIntervalSince1970) < 1)
    }
    
    @Test("Target calculates max allowable time over IP correctly")
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
        
        guard let maxAllowableTimeOverIP = target.maxAllowableTimeOverIP else {
            throw ExpectationFailedError("maxAllowableTimeOverIP should not be nil")
        }
        
        // Should be about 5.45 minutes before TOT
        let expectedTime = tot.addingTimeInterval(-5.45 * 60)
        #expect(abs(maxAllowableTimeOverIP.timeIntervalSince1970 - expectedTime.timeIntervalSince1970) < 5)
    }
}
