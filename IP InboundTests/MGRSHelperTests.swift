import MeasurementKitLocation
import Numerics
import Testing

@testable import IP_Inbound
@testable import IP_Inbound_Shared

@Suite
struct `MGRSHelper tests` {

  @Test
  func `Partial MGRS validation doesn't crash`() {
    // These should all return false without crashing
    #expect(!MGRSHelper.validate(""))  // Empty
    #expect(!MGRSHelper.validate("3"))  // Just zone start
    #expect(!MGRSHelper.validate("33"))  // Just zone
    #expect(MGRSHelper.validate("33X"))  // Zone + band (valid minimal format)
    #expect(!MGRSHelper.validate("33XV"))  // Zone + band + partial square

    // Valid formats
    #expect(MGRSHelper.validate("33XVG"))  // Zone + band + square
    #expect(MGRSHelper.validate("33XVG74"))  // + 1 digit precision
    #expect(MGRSHelper.validate("33XVG7459"))  // + 2 digit precision
    #expect(MGRSHelper.validate("33XVG745593"))  // + 3 digit precision
    #expect(MGRSHelper.validate("33XVG74595936"))  // + 4 digit precision
    #expect(MGRSHelper.validate("33XVG7459459364"))  // + 5 digit precision (max)
  }

  @Test
  func `Invalid character validation doesn't crash`() {
    #expect(!MGRSHelper.validate("33I"))  // Invalid band letter I
    #expect(!MGRSHelper.validate("33O"))  // Invalid band letter O
    #expect(!MGRSHelper.validate("61X"))  // Invalid zone > 60
    #expect(!MGRSHelper.validate("0X"))  // Invalid zone 0
    #expect(!MGRSHelper.validate("33XVG745A"))  // Letter in coordinates
    #expect(!MGRSHelper.validate("33XVG74593"))  // Odd number of coordinate digits
  }

  @Test
  func `MGRS formatting works correctly`() {
    // Test with spaces
    #expect(MGRSHelper.format("33XVG745593", withSpaces: true) == "33X VG 745 593")
    #expect(MGRSHelper.format("33XVG", withSpaces: true) == "33X VG")

    // Test without spaces
    #expect(MGRSHelper.format("33XVG745593", withSpaces: false) == "33XVG745593")

    // Test normalization
    #expect(MGRSHelper.format("33x vg 745 593", withSpaces: false) == "33XVG745593")
    #expect(MGRSHelper.format("33X-VG-745-593", withSpaces: true) == "33X VG 745 593")
  }

  @Test
  func `Coordinate conversion works with valid strings`() throws {
    // Known coordinate: Oslo, Norway
    let oslo = Coordinate(latitude: 59.9139, longitude: 10.7522)
    let mgrs = try #require(MGRSHelper.fromCoordinate(oslo, precision: .oneM))
    // Should produce something like "32V NM 89455 60642"
    #expect(mgrs.contains("32V"))
    #expect(mgrs.contains("NM") || mgrs.contains("NN"))  // Grid square may vary

    // Test roundtrip
    let hundredMeterMGRS = try #require(MGRSHelper.fromCoordinate(oslo, precision: .hundredM))
    let backToCoord = try #require(MGRSHelper.toCoordinate(hundredMeterMGRS))
    #expect(
      backToCoord.latitudeDeg.isApproximatelyEqual(to: oslo.latitudeDeg, absoluteTolerance: 0.01)
    )
    #expect(
      backToCoord.longitudeDeg.isApproximatelyEqual(
        to: oslo.longitudeDeg,
        absoluteTolerance: 0.01
      )
    )
  }

  @Test
  func `toCoordinate returns nil for invalid inputs without crashing`() {
    #expect(MGRSHelper.toCoordinate("") == nil)
    #expect(MGRSHelper.toCoordinate("33") == nil)
    // "33X" is valid MGRS (zone + band) and can be parsed to a coordinate
    #expect(MGRSHelper.toCoordinate("33X") != nil)
    #expect(MGRSHelper.toCoordinate("33XV") == nil)
    #expect(MGRSHelper.toCoordinate("33XVG74593") == nil)  // Odd digits
    #expect(MGRSHelper.toCoordinate("61XVG745593") == nil)  // Invalid zone
    #expect(MGRSHelper.toCoordinate("33IVG745593") == nil)  // Invalid band
  }
}
