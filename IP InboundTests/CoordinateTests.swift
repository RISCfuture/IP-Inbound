import Foundation
@testable import IP_Inbound
import Testing

@Suite("Coordinate")
struct CoordinateTests {
    @Test("distance, calculates correctly")
    func testCoordinateDistance() throws {
        let coord1 = Coordinate(latitude: 0, longitude: 0)
        let coord2 = Coordinate(latitude: 1, longitude: 0)

        // 1 degree of latitude is approximately 60 nautical miles
        let distance = coord1.distance(to: coord2)
        #expect(abs(distance.converted(to: .nauticalMiles).value - 60) < 0.5)
    }

    @Test("bearing, calculates correctly")
    func testCoordinateBearing() throws {
        let coord1 = Coordinate(latitude: 0, longitude: 0)
        let coord2 = Coordinate(latitude: 0, longitude: 1) // Due east

        let bearing = coord1.bearing(to: coord2)
        #expect(abs(bearing.degrees - 90) < 0.5)

        let coord3 = Coordinate(latitude: 1, longitude: 0) // Due north
        let bearing2 = coord1.bearing(to: coord3)
        #expect(abs(bearing2.degrees - 0) < 0.5)
    }

    @Test("offsetBy, calculates correctly")
    func testCoordinateOffset() throws {
        let start = Coordinate(latitude: 0, longitude: 0)

        // Offset 60NM north
        let northOffset = start.offsetBy(
            bearing: .init(value: 0, unit: .degrees),
            distance: Measurement(value: 60, unit: .nauticalMiles)
        )
        #expect(abs(northOffset.latitudeDeg - 1) < 0.01)
        #expect(abs(northOffset.longitudeDeg - 0) < 0.01)

        // Offset 60NM east
        let eastOffset = start.offsetBy(
            bearing: .init(value: 90, unit: .degrees),
            distance: Measurement(value: 60, unit: .nauticalMiles)
        )
        #expect(abs(eastOffset.latitudeDeg - 0) < 0.01)
        #expect(abs(eastOffset.longitudeDeg - 1) < 0.01)
    }

    // MARK: - Bearing Tests

}
