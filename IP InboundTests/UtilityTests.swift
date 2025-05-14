@testable import IP_Inbound
import CoreLocation
import Testing

@Suite("Utility Tests")
struct UtilityTests {
    
    // MARK: - FromToMath Tests
    
    @Test("FromToMath calculates bearing correctly")
    func testFromToMathBearing() throws {
        // Create test coordinates
        let from = Coordinate(latitude: 37.7749, longitude: -122.4194) // San Francisco
        let to = Coordinate(latitude: 34.0522, longitude: -118.2437)   // Los Angeles
        
        // Create FromToMath with test data
        let fromTo = FromToMath(
            from: from,
            to: to,
            speed: Measurement(value: 120, unit: .knots),
            track: Bearing(angle: 150, reference: .true),
            targetSpeed: Measurement(value: 120, unit: .knots),
            timeOnTarget: Date.now.addingTimeInterval(3600),
            declination: Measurement(value: 13, unit: .degrees)
        )
        
        // Test bearing calculation (value is approximate)
        #expect(abs(fromTo.bearing.degrees - 144.3) < 0.5)
    }
    
    @Test("FromToMath calculates distance correctly")
    func testFromToMathDistance() throws {
        // Create test coordinates about 100NM apart
        let from = Coordinate(latitude: 37.0, longitude: -122.0)
        let to = Coordinate(latitude: 38.0, longitude: -122.0)
        
        // Create FromToMath with test data
        let fromTo = FromToMath(
            from: from,
            to: to,
            speed: Measurement(value: 120, unit: .knots),
            track: Bearing(angle: 0, reference: .true),
            targetSpeed: Measurement(value: 120, unit: .knots),
            timeOnTarget: Date.now.addingTimeInterval(3600),
            declination: Measurement(value: 0, unit: .degrees)
        )
        
        // Test distance calculation (should be about 60NM)
        #expect(abs(fromTo.distance.converted(to: .nauticalMiles).value - 60) < 1)
    }
    
    @Test("FromToMath calculates time to go correctly - straight line")
    func testFromToMathTimeToGoStraightLine() throws {
        // Create test coordinates
        let from = Coordinate(latitude: 37.0, longitude: -122.0)
        let to = Coordinate(latitude: 38.0, longitude: -122.0)
        
        // Speed = 120 knots, distance = ~60NM, so time should be 0.5 hours or 30 minutes
        let fromTo = FromToMath(
            from: from,
            to: to,
            speed: Measurement(value: 120, unit: .knots),
            track: Bearing(angle: 0, reference: .true), // Track aligned with bearing
            targetSpeed: Measurement(value: 120, unit: .knots),
            timeOnTarget: Date.now.addingTimeInterval(3600),
            declination: Measurement(value: 0, unit: .degrees)
        )
        
        // Test timeToGo calculation (should be about 30 minutes)
        #expect(abs(fromTo.timeToGo.converted(to: .minutes).value - 30) < 1)
    }
    
    @Test("FromToMath calculates time to go correctly - with turn")
    func testFromToMathTimeToGoWithTurn() throws {
        // Create test coordinates
        let from = Coordinate(latitude: 37.0, longitude: -122.0)
        let to = Coordinate(latitude: 38.0, longitude: -122.0)
        
        // Speed = 120 knots, distance = ~60NM, so straight line time would be 30 minutes
        // But we're heading 90 degrees off course, so need to turn
        let fromTo = FromToMath(
            from: from,
            to: to,
            speed: Measurement(value: 120, unit: .knots),
            track: Bearing(angle: 90, reference: .true), // Track is 90 degrees off bearing to target
            targetSpeed: Measurement(value: 120, unit: .knots),
            timeOnTarget: Date.now.addingTimeInterval(3600),
            declination: Measurement(value: 0, unit: .degrees)
        )
        
        // Test timeToGo calculation - should be more than straight line due to turn time
        #expect(fromTo.timeToGo.converted(to: .minutes).value > 30)
    }
    
    @Test("FromToMath calculates TOT delta correctly")
    func testFromToMathTOTDelta() throws {
        // Create test coordinates
        let from = Coordinate(latitude: 37.0, longitude: -122.0)
        let to = Coordinate(latitude: 38.0, longitude: -122.0)
        
        // Distance is ~60NM, speed is 120 knots, so timeToGo is 0.5 hours
        // TOT is 1 hour away, so we should be 0.5 hours (30 minutes) early
        let tot = Date.now.addingTimeInterval(3600) // 1 hour from now
        let fromTo = FromToMath(
            from: from,
            to: to,
            speed: Measurement(value: 120, unit: .knots),
            track: Bearing(angle: 0, reference: .true),
            targetSpeed: Measurement(value: 120, unit: .knots),
            timeOnTarget: tot,
            declination: Measurement(value: 0, unit: .degrees)
        )
        
        // Test deltaTOT calculation - should be negative (early)
        #expect(abs(fromTo.deltaTOT - (-1800)) < 60) // Allow a minute of tolerance
        #expect(fromTo.isEarly)
        #expect(!fromTo.isLate)
    }
    
    // MARK: - IPTargetMath Tests
    
    @Test("IPTargetMath detects position past IP correctly - past")
    func testIPTargetMathIsPastIPWhenPast() throws {
        // Set up a target
        let target = Target(name: "Test Target", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        // Set the IP 4NM away on a 180° bearing (i.e., due south of target)
        target.offsetBearing = 180
        target.offsetDistance = 4
        
        // Position is 1NM past the IP towards the target (north of IP, south of target)
        let position = Coordinate(latitude: 37.97, longitude: -122.0) // Just past IP towards target
        
        let ipTargetMath = IPTargetMath(
            coordinate: position,
            speed: Measurement(value: 120, unit: .knots),
            course: Bearing(angle: 0, reference: .true),
            target: target
        )
        
        #expect(ipTargetMath.isPastIP)
    }
    
    @Test("IPTargetMath detects position past IP correctly - not past")
    func testIPTargetMathIsPastIPWhenNotPast() throws {
        // Set up a target
        let target = Target(name: "Test Target", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        // Set the IP 4NM away on a 180° bearing (i.e., due south of target)
        target.offsetBearing = 180
        target.offsetDistance = 4
        
        // Position is 1NM before reaching the IP (further south from IP)
        let position = Coordinate(latitude: 37.93, longitude: -122.0) // Before IP
        
        let ipTargetMath = IPTargetMath(
            coordinate: position,
            speed: Measurement(value: 120, unit: .knots),
            course: Bearing(angle: 0, reference: .true),
            target: target
        )
        
        #expect(!ipTargetMath.isPastIP)
    }
    
    @Test("IPTargetMath calculates IP ETA correctly")
    func testIPTargetMathIPETA() throws {
        // Set up a target with TOT
        let target = Target(name: "Test Target", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        target.offsetBearing = 180
        target.offsetDistance = 4
        target.timeOnTarget = Date.now.addingTimeInterval(3600) // 1 hour from now
        
        // Position is 60NM from IP, speed is 120 knots, so ETA should be 30 minutes
        let position = Coordinate(latitude: 37.0, longitude: -122.0) // 60NM south of IP
        
        let ipTargetMath = IPTargetMath(
            coordinate: position,
            speed: Measurement(value: 120, unit: .knots),
            course: Bearing(angle: 0, reference: .true),
            target: target
        )
        
        // Check that we have a valid ETA
        #expect(ipTargetMath.IP_ETA != nil)
        
        if let eta = ipTargetMath.IP_ETA {
            // Should be about 30 minutes from now
            #expect(abs(eta.timeIntervalSinceNow - 1800) < 60)
        }
    }
    
    @Test("IPTargetMath calculates delta times correctly")
    func testIPTargetMathDeltaTimes() throws {
        // Set up a target with TOT
        let target = Target(name: "Test Target", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        target.offsetBearing = 180
        target.offsetDistance = 4
        target.targetGroundSpeed = 120 // 120 knots
        target.timeOnTarget = Date.now.addingTimeInterval(3600) // 1 hour from now
        
        // IP to target is 4NM at 120 knots = 2 minutes
        // So desired time over IP is 58 minutes from now
        
        // Position is 15NM from IP, speed is 120 knots, so ETA should be 7.5 minutes
        // This means we'll reach IP 50.5 minutes before TOT, but we want to be there 58 minutes before TOT
        // So we're about 7.5 minutes "late" to IP
        let position = Coordinate(latitude: 37.75, longitude: -122.0) // 15NM south of IP
        
        let ipTargetMath = IPTargetMath(
            coordinate: position,
            speed: Measurement(value: 120, unit: .knots),
            course: Bearing(angle: 0, reference: .true),
            target: target
        )
        
        // Check IPDeltaTime (should be positive, indicating we're late)
        #expect(ipTargetMath.IPDeltaTime != nil)
        
        if let deltaTime = ipTargetMath.IPDeltaTime {
            // Should be about 7.5 minutes (450 seconds)
            #expect(abs(deltaTime - 450) < 60)
        }
    }
    
    @Test("IPTargetMath calculates cross track distance correctly")
    func testIPTargetMathCrossTrackDistance() throws {
        // Set up a target
        let target = Target(name: "Test Target", coordinate: Coordinate(latitude: 38.0, longitude: -122.0))
        target.offsetBearing = 180 // IP is due south of target
        target.offsetDistance = 4  // IP is 4NM south of target
        
        // Position is 10NM south of target but 1NM east (offset from direct line)
        let position = Coordinate(latitude: 37.9, longitude: -121.98) // Off to the side
        
        let ipTargetMath = IPTargetMath(
            coordinate: position,
            speed: Measurement(value: 120, unit: .knots),
            course: Bearing(angle: 0, reference: .true),
            target: target
        )
        
        // Cross track distance should be close to 1NM
        #expect(abs(ipTargetMath.crossTrackDistance.converted(to: .nauticalMiles).value - 1) < 0.2)
    }
    
    // MARK: - Coordinate Tests
    
    @Test("Coordinate calculates distance correctly")
    func testCoordinateDistance() throws {
        let coord1 = Coordinate(latitude: 0, longitude: 0)
        let coord2 = Coordinate(latitude: 1, longitude: 0)
        
        // 1 degree of latitude is approximately 60 nautical miles
        let distance = coord1.distance(to: coord2)
        #expect(abs(distance.converted(to: .nauticalMiles).value - 60) < 0.5)
    }
    
    @Test("Coordinate calculates bearing correctly")
    func testCoordinateBearing() throws {
        let coord1 = Coordinate(latitude: 0, longitude: 0)
        let coord2 = Coordinate(latitude: 0, longitude: 1) // Due east
        
        let bearing = coord1.bearing(to: coord2)
        #expect(abs(bearing.degrees - 90) < 0.5)
        
        let coord3 = Coordinate(latitude: 1, longitude: 0) // Due north
        let bearing2 = coord1.bearing(to: coord3)
        #expect(abs(bearing2.degrees - 0) < 0.5)
    }
    
    @Test("Coordinate offsets correctly")
    func testCoordinateOffset() throws {
        let start = Coordinate(latitude: 0, longitude: 0)
        
        // Offset 60NM north
        let northOffset = start.offsetBy(
            bearing: 0,
            distance: Measurement(value: 60, unit: .nauticalMiles)
        )
        #expect(abs(northOffset.latitudeDeg - 1) < 0.01)
        #expect(abs(northOffset.longitudeDeg - 0) < 0.01)
        
        // Offset 60NM east
        let eastOffset = start.offsetBy(
            bearing: 90,
            distance: Measurement(value: 60, unit: .nauticalMiles)
        )
        #expect(abs(eastOffset.latitudeDeg - 0) < 0.01)
        #expect(abs(eastOffset.longitudeDeg - 1) < 0.01)
    }
    
    // MARK: - Bearing Tests
    
    @Test("Bearing normalizes angles correctly")
    func testBearingNormalization() throws {
        // Test that 370 degrees normalizes to 10 degrees
        let bearing1 = Bearing(angle: 370, reference: .true)
        #expect(abs(bearing1.degrees - 10) < 0.01)
        
        // Test that -10 degrees normalizes to 350 degrees
        let bearing2 = Bearing(angle: -10, reference: .true)
        #expect(abs(bearing2.degrees - 350) < 0.01)
    }
    
    @Test("Bearing calculates reciprocal correctly")
    func testBearingReciprocal() throws {
        let bearing = Bearing(angle: 30, reference: .true)
        let reciprocal = bearing.reciprocal
        #expect(abs(reciprocal.degrees - 210) < 0.01)
        
        let bearing2 = Bearing(angle: 200, reference: .magnetic)
        let reciprocal2 = bearing2.reciprocal
        #expect(abs(reciprocal2.degrees - 20) < 0.01)
        #expect(reciprocal2.reference == bearing2.reference)
    }
    
    @Test("Bearing converts between true and magnetic correctly")
    func testBearingConversion() throws {
        let trueBearing = Bearing(angle: 10, reference: .true)
        let declination = Measurement(value: 15, unit: .degrees)
        
        let magneticBearing = trueBearing.toMagnetic(declination: declination)
        #expect(abs(magneticBearing.degrees - 355) < 0.01)
        #expect(magneticBearing.reference == .magnetic)
        
        let convertedBack = magneticBearing.toTrue(declination: declination)
        #expect(abs(convertedBack.degrees - 10) < 0.01)
        #expect(convertedBack.reference == .true)
    }
}