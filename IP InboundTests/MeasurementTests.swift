import Foundation
@testable import IP_Inbound
import Numerics
import Testing

@Suite("Measurement")
struct MeasurementTests {

    @Test("Division, of length by duration produces correct speed")
    func testLengthDividedByDurationEqualsSpeed() throws {
        // 100 meters / 10 seconds = 10 meters per second
        let length = Measurement(value: 100, unit: UnitLength.meters),
            duration = Measurement(value: 10, unit: UnitDuration.seconds),
            speed = length / duration

        #expect(speed.unit == UnitSpeed.metersPerSecond)
        #expect(speed.value == 10)
    }

    @Test("Division, of length by speed produces correct duration")
    func testLengthDividedBySpeedEqualsDuration() throws {
        // 100 meters / 10 meters per second = 10 seconds
        let length = Measurement(value: 100, unit: UnitLength.meters),
            speed = Measurement(value: 10, unit: UnitSpeed.metersPerSecond),
            duration = length / speed

        #expect(duration.unit == UnitDuration.seconds)
        #expect(duration.value == 10)
    }

    @Test("Division, of same unit measurements produces correct ratio")
    func testDivisionOfSameUnitProducesRatio() throws {
        // 100 meters / 50 meters = 2
        let length1 = Measurement(value: 100, unit: UnitLength.meters),
            length2 = Measurement(value: 50, unit: UnitLength.meters),
            ratio = length1 / length2

        #expect(ratio == 2)

        // Test with different units of same dimension
        let length3 = Measurement(value: 1, unit: UnitLength.kilometers),
            length4 = Measurement(value: 100, unit: UnitLength.meters),
            ratio2 = length3 / length4

        #expect(ratio2 == 10)
    }

    @Test("Multiplication, of speed by duration produces correct length")
    func testSpeedMultipliedByDurationEqualsLength() throws {
        // 10 meters per second * 10 seconds = 100 meters
        let speed = Measurement(value: 10, unit: UnitSpeed.metersPerSecond),
            duration = Measurement(value: 10, unit: UnitDuration.seconds),
            length = speed * duration

        #expect(length.unit == UnitLength.meters)
        #expect(length.value == 100)
    }

    @Test("tan, works correctly with measurements")
    func testTangentWithMeasurements() throws {
        // tan(45 degrees) = 1
        let angle = Measurement(value: 45, unit: UnitAngle.degrees),
            result = tan(angle)

        #expect(result.isApproximatelyEqual(to: 1))
    }

    @Test("Duration, afterNow, produces correct date")
    func testDurationAfterNow() throws {
        let duration = Measurement(value: 60, unit: UnitDuration.seconds),
            future = duration.afterNow

        // Should be about 60 seconds after now
        #expect(future.timeIntervalSince(.now).isApproximatelyEqual(to: 60, relativeTolerance: 0.01))
    }

    @Test("Duration, beforeNow ,produces correct date")
    func testDurationBeforeNow() throws {
        let duration = Measurement(value: 60, unit: UnitDuration.seconds),
            past = duration.beforeNow

        // Should be about 60 seconds before now
        #expect(Date.now.timeIntervalSince(past).isApproximatelyEqual(to: 60, relativeTolerance: 0.01))
    }

    @Test("Duration, after, produces correct date")
    func testDurationAfterDate() throws {
        let duration = Measurement(value: 120, unit: UnitDuration.seconds),
            referenceDate = Date.now,
            future = duration.after(date: referenceDate)

        // Should be exactly 120 seconds after reference date
        #expect(future.timeIntervalSince(referenceDate).isApproximatelyEqual(to: 120))
    }

    @Test("Duration, before, produces correct date")
    func testDurationBeforeDate() throws {
        let duration = Measurement(value: 120, unit: UnitDuration.seconds),
            referenceDate = Date.now,
            past = duration.before(date: referenceDate)

        // Should be exactly 120 seconds before reference date
        #expect(referenceDate.timeIntervalSince(past).isApproximatelyEqual(to: 120))
    }
}
