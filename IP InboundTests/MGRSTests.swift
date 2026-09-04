import Foundation
import MeasurementKitLocation
import Numerics
import Testing

@testable import IP_Inbound
@testable import IP_Inbound_Shared

@Suite("MGRS")
struct MGRSTests {

  @Test("Coordinate to MGRS conversion")
  func coordinateToMGRS() throws {
    // Test known coordinate conversions
    let testCases: [(lat: Double, lon: Double, expectedPrefix: String)] = [
      // Washington DC area
      (38.8977, -77.0365, "18S"),
      // London area
      (51.5074, -0.1278, "30U"),
      // Sydney area
      (-33.8688, 151.2093, "56H"),
      // Tokyo area
      (35.6762, 139.6503, "54S")
    ]

    for testCase in testCases {
      let coordinate = Coordinate(latitude: testCase.lat, longitude: testCase.lon)
      let mgrs = try #require(
        MGRSHelper.fromCoordinate(coordinate, precision: .oneM),
        "MGRS conversion failed for lat: \(testCase.lat), lon: \(testCase.lon)"
      )
      #expect(
        mgrs.hasPrefix(testCase.expectedPrefix),
        "MGRS \(mgrs) doesn't start with expected prefix \(testCase.expectedPrefix)"
      )
    }
  }

  @Test("MGRS to coordinate parsing")
  func mgrsToCoordinate() throws {
    // Test parsing various MGRS formats
    // Note: These are real MGRS strings with their actual parsed coordinates
    let testCases: [(mgrs: String, expectedLat: Double, expectedLon: Double, tolerance: Double)] = [
      // Washington DC area - verified MGRS string
      ("18S UJ 23487 06483", 38.88949, -77.03519, 0.001),  // Near Washington Monument

      // Test different formats with spaces - using same coordinate
      ("18SUJ2348706483", 38.88949, -77.03519, 0.001),
      ("18S UJ 23487 06483", 38.88949, -77.03519, 0.001),

      // Lower precision (100m)
      ("18SUJ23480648", 38.8894, -77.0352, 0.01),

      // Even lower precision (1km)
      ("18SUJ2306", 38.889, -77.035, 0.1)
    ]

    for testCase in testCases {
      let coordinate = try #require(
        MGRSHelper.toCoordinate(testCase.mgrs),
        "Failed to parse MGRS: \(testCase.mgrs)"
      )
      #expect(
        coordinate.latitudeDeg.isApproximatelyEqual(
          to: testCase.expectedLat,
          absoluteTolerance: testCase.tolerance
        ),
        "Latitude mismatch for MGRS: \(testCase.mgrs)"
      )
      #expect(
        coordinate.longitudeDeg.isApproximatelyEqual(
          to: testCase.expectedLon,
          absoluteTolerance: testCase.tolerance
        ),
        "Longitude mismatch for MGRS: \(testCase.mgrs)"
      )
    }
  }

  @Test("MGRS precision levels")
  func mgrsPrecisionLevels() throws {
    let coordinate = Coordinate(latitude: 38.8977, longitude: -77.0365)

    let precisionTests: [(precision: MGRSHelper.Precision, expectedLength: Int)] = [
      (.gridZone, 3),  // e.g., "18S"
      (.hundredKm, 5),  // e.g., "18SUJ"
      (.tenKm, 7),  // e.g., "18SUJ23"
      (.oneKm, 9),  // e.g., "18SUJ2306"
      (.hundredM, 11),  // e.g., "18SUJ23406"
      (.tenM, 13),  // e.g., "18SUJ2348706"
      (.oneM, 15)  // e.g., "18SUJ234870648"
    ]

    for test in precisionTests {
      let mgrs = try #require(
        MGRSHelper.fromCoordinate(coordinate, precision: test.precision),
        "Failed to generate MGRS at precision: \(test.precision)"
      )
      let cleanMGRS = mgrs.replacingOccurrences(of: " ", with: "")
      #expect(
        cleanMGRS.count == test.expectedLength,
        "MGRS length mismatch for precision \(test.precision): got \(cleanMGRS)"
      )
    }
  }
}
