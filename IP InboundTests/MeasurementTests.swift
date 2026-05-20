import Foundation
import Numerics
import Testing

@testable import IP_Inbound

@Suite("Measurement")
struct MeasurementTests {

  @Test("Division, of length by duration produces correct speed")
  func testLengthDividedByDurationEqualsSpeed() throws {
    // 100 meters / 10 seconds = 10 meters per second
    let length = Measurement(value: 100, unit: UnitLength.meters)
    let duration = Measurement(value: 10, unit: UnitDuration.seconds)
    let speed = length / duration

    #expect(speed.unit == UnitSpeed.metersPerSecond)
    #expect(speed.value == 10)
  }

  @Test("Division, of length by speed produces correct duration")
  func testLengthDividedBySpeedEqualsDuration() throws {
    // 100 meters / 10 meters per second = 10 seconds
    let length = Measurement(value: 100, unit: UnitLength.meters)
    let speed = Measurement(value: 10, unit: UnitSpeed.metersPerSecond)
    let duration = length / speed

    #expect(duration.unit == UnitDuration.seconds)
    #expect(duration.value == 10)
  }

  @Test("Division, of same unit measurements produces correct ratio")
  func testDivisionOfSameUnitProducesRatio() throws {
    // 100 meters / 50 meters = 2
    let length1 = Measurement(value: 100, unit: UnitLength.meters)
    let length2 = Measurement(value: 50, unit: UnitLength.meters)
    let ratio = length1 / length2

    #expect(ratio == 2)

    // Test with different units of same dimension
    let length3 = Measurement(value: 1, unit: UnitLength.kilometers)
    let length4 = Measurement(value: 100, unit: UnitLength.meters)
    let ratio2 = length3 / length4

    #expect(ratio2 == 10)
  }

  @Test("Multiplication, of speed by duration produces correct length")
  func testSpeedMultipliedByDurationEqualsLength() throws {
    // 10 meters per second * 10 seconds = 100 meters
    let speed = Measurement(value: 10, unit: UnitSpeed.metersPerSecond)
    let duration = Measurement(value: 10, unit: UnitDuration.seconds)
    let length = speed * duration

    #expect(length.unit == UnitLength.meters)
    #expect(length.value == 100)
  }

  @Test("tan, works correctly with measurements")
  func testTangentWithMeasurements() throws {
    // tan(45 degrees) = 1
    let angle = Measurement(value: 45, unit: UnitAngle.degrees)
    let result = tan(angle)

    #expect(result.isApproximatelyEqual(to: 1))
  }

  @Test("Duration, after, produces correct date")
  func testDurationAfterDate() throws {
    let duration = Measurement(value: 120, unit: UnitDuration.seconds)
    let referenceDate = Date.now
    let future = duration.after(date: referenceDate)

    // Should be exactly 120 seconds after reference date
    #expect(future.timeIntervalSince(referenceDate).isApproximatelyEqual(to: 120))
  }

  @Test("Duration, before, produces correct date")
  func testDurationBeforeDate() throws {
    let duration = Measurement(value: 120, unit: UnitDuration.seconds)
    let referenceDate = Date.now
    let past = duration.before(date: referenceDate)

    // Should be exactly 120 seconds before reference date
    #expect(referenceDate.timeIntervalSince(past).isApproximatelyEqual(to: 120))
  }
}
