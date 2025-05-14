@testable import IP_Inbound
import Foundation
import Testing

@Suite("Measurement Tests")
struct MeasurementTests {
    
    @Test("Division of length by duration produces correct speed")
    func testLengthDividedByDurationEqualsSpeed() throws {
        // 100 meters / 10 seconds = 10 meters per second
        let length = Measurement(value: 100, unit: UnitLength.meters)
        let duration = Measurement(value: 10, unit: UnitDuration.seconds)
        
        let speed = length / duration
        
        #expect(speed.unit == UnitSpeed.metersPerSecond)
        #expect(abs(speed.value - 10) < 0.001)
    }
    
    @Test("Division of length by speed produces correct duration")
    func testLengthDividedBySpeedEqualsDuration() throws {
        // 100 meters / 10 meters per second = 10 seconds
        let length = Measurement(value: 100, unit: UnitLength.meters)
        let speed = Measurement(value: 10, unit: UnitSpeed.metersPerSecond)
        
        let duration = length / speed
        
        #expect(duration.unit == UnitDuration.seconds)
        #expect(abs(duration.value - 10) < 0.001)
    }
    
    @Test("Division of same unit measurements produces correct ratio")
    func testDivisionOfSameUnitProducesRatio() throws {
        // 100 meters / 50 meters = 2
        let length1 = Measurement(value: 100, unit: UnitLength.meters)
        let length2 = Measurement(value: 50, unit: UnitLength.meters)
        
        let ratio = length1 / length2
        
        #expect(abs(ratio - 2) < 0.001)
        
        // Test with different units of same dimension
        let length3 = Measurement(value: 1, unit: UnitLength.kilometers)
        let length4 = Measurement(value: 100, unit: UnitLength.meters)
        
        let ratio2 = length3 / length4
        
        #expect(abs(ratio2 - 10) < 0.001)
    }
    
    @Test("Multiplication of speed by duration produces correct length")
    func testSpeedMultipliedByDurationEqualsLength() throws {
        // 10 meters per second * 10 seconds = 100 meters
        let speed = Measurement(value: 10, unit: UnitSpeed.metersPerSecond)
        let duration = Measurement(value: 10, unit: UnitDuration.seconds)
        
        let length = speed * duration
        
        #expect(length.unit == UnitLength.meters)
        #expect(abs(length.value - 100) < 0.001)
    }
    
    @Test("Tangent function works correctly with measurements")
    func testTangentWithMeasurements() throws {
        // tan(45 degrees) = 1
        let angle = Measurement(value: 45, unit: UnitAngle.degrees)
        
        let result = tan(angle)
        
        #expect(result.unit == UnitAngle.degrees)
        #expect(abs(result.value - 1) < 0.001)
    }
    
    @Test("Duration afterNow produces correct date")
    func testDurationAfterNow() throws {
        let duration = Measurement(value: 60, unit: UnitDuration.seconds)
        let now = Date.now
        
        let future = duration.afterNow
        
        // Should be about 60 seconds after now
        #expect(abs(future.timeIntervalSince(now) - 60) < 1)
    }
    
    @Test("Duration beforeNow produces correct date")
    func testDurationBeforeNow() throws {
        let duration = Measurement(value: 60, unit: UnitDuration.seconds)
        let now = Date.now
        
        let past = duration.beforeNow
        
        // Should be about 60 seconds before now
        #expect(abs(now.timeIntervalSince(past) - 60) < 1)
    }
    
    @Test("Duration after date produces correct date")
    func testDurationAfterDate() throws {
        let duration = Measurement(value: 120, unit: UnitDuration.seconds)
        let referenceDate = Date.now
        
        let future = duration.after(date: referenceDate)
        
        // Should be exactly 120 seconds after reference date
        #expect(abs(future.timeIntervalSince(referenceDate) - 120) < 0.001)
    }
    
    @Test("Duration before date produces correct date")
    func testDurationBeforeDate() throws {
        let duration = Measurement(value: 120, unit: UnitDuration.seconds)
        let referenceDate = Date.now
        
        let past = duration.before(date: referenceDate)
        
        // Should be exactly 120 seconds before reference date
        #expect(abs(referenceDate.timeIntervalSince(past) - 120) < 0.001)
    }
    
    @Test("Unit conversions maintain accuracy")
    func testUnitConversions() throws {
        // 1 NM = 1852 meters
        let nauticalMiles = Measurement(value: 1, unit: UnitLength.nauticalMiles)
        let meters = nauticalMiles.converted(to: .meters)
        
        #expect(abs(meters.value - 1852) < 0.1)
        
        // 60 knots = 30.87 meters per second
        let knots = Measurement(value: 60, unit: UnitSpeed.knots)
        let metersPerSecond = knots.converted(to: .metersPerSecond)
        
        #expect(abs(metersPerSecond.value - 30.87) < 0.1)
        
        // 1 hour = 3600 seconds
        let hours = Measurement(value: 1, unit: UnitDuration.hours)
        let seconds = hours.converted(to: .seconds)
        
        #expect(seconds.value == 3600)
    }
}
