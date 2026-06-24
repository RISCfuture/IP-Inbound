import Foundation
import Testing

@testable import IP_Inbound

@Suite("Bearing")
struct BearingTests {
  @Test("normalized, calculates correctly")
  func bearingNormalization() {
    let bearing1 = Bearing(angle: 370, reference: .true)
    #expect(bearing1.normalized.degrees == 10)

    let bearing2 = Bearing(angle: -10, reference: .true)
    #expect(bearing2.normalized.degrees == 350)
  }

  @Test("reciprocal, calculates correctly")
  func bearingReciprocal() {
    let bearing = Bearing(angle: 30, reference: .true)
    #expect(bearing.reciprocal.degrees == 210)
    #expect(bearing.reciprocal.reference == bearing.reference)

    let bearing2 = Bearing(angle: 200, reference: .magnetic)
    #expect(bearing2.reciprocal.degrees == 20)
    #expect(bearing2.reciprocal.reference == bearing2.reference)
  }

  @Test("shortestTurn, picks the shorter direction across the 0/360 wrap")
  func bearingShortestTurn() {
    let north = Bearing(angle: 350, reference: .magnetic)
    let east = Bearing(angle: 10, reference: .magnetic)

    let rightTurn = north.shortestTurn(to: east)
    #expect(rightTurn.degrees == 20)
    #expect(rightTurn.reference == .relative)

    let leftTurn = east.shortestTurn(to: north)
    #expect(leftTurn.degrees == -20)
  }

  @Test("toMagnetic and toTrue, calculates correctly")
  func bearingConversion() {
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
