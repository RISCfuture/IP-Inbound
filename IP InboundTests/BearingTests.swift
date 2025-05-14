import Foundation
@testable import IP_Inbound
import Testing

@Suite("Bearing")
struct BearingTests {
    @Test("normalized, calculates correctly")
    func testBearingNormalization() throws {
        let bearing1 = Bearing(angle: 370, reference: .true)
        #expect(bearing1.normalized.degrees == 10)

        let bearing2 = Bearing(angle: -10, reference: .true)
        #expect(bearing2.normalized.degrees == 350)
    }

    @Test("reciprocal, calulates correctly")
    func testBearingReciprocal() throws {
        let bearing = Bearing(angle: 30, reference: .true)
        #expect(bearing.reciprocal.degrees == 210)
        #expect(bearing.reciprocal.reference == bearing.reference)

        let bearing2 = Bearing(angle: 200, reference: .magnetic)
        #expect(bearing2.reciprocal.degrees == 20)
        #expect(bearing2.reciprocal.reference == bearing2.reference)
    }

    @Test("toMagnetic and toTrue, calculates correctly")
    func testBearingConversion() throws {
        let trueBearing = Bearing(angle: 10, reference: .true)
        let declination = Measurement(value: 15, unit: UnitAngle.degrees)

        let magneticBearing = trueBearing.toMagnetic(declination: declination)
        #expect(magneticBearing.degrees == 355)
        #expect(magneticBearing.reference == .magnetic)

        let convertedBack = magneticBearing.toTrue(declination: declination)
        #expect(convertedBack.degrees == 10)
        #expect(convertedBack.reference == .true)
    }
}
