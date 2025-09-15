import CoreLocation
import Foundation

// MARK: - UTM Converter

/// A utility for converting between UTM (Universal Transverse Mercator) coordinates and latitude/longitude.
public enum UTMConverter {
    // WGS84 Ellipsoid constants
    private static let a = 6378137.0  // Semi-major axis
    private static let f = 1.0 / 298.257223563  // Flattening
    private static let b = a * (1.0 - f)  // Semi-minor axis
    private static let e = sqrt(1.0 - (b * b) / (a * a))  // Eccentricity
    private static let e2 = e * e
    private static let e4 = e2 * e2
    private static let e6 = e4 * e2
    private static let k0 = 0.9996  // Scale factor

    // MARK: - Lat/Lon to UTM

    /// Converts latitude and longitude coordinates to UTM.
    /// - Parameters:
    ///   - latitude: The latitude in degrees.
    ///   - longitude: The longitude in degrees.
    /// - Returns: The corresponding UTM coordinate.
    public static func fromLatLon(latitude: Double, longitude: Double) -> UTMCoordinate {
        let zone = calculateZone(longitude: longitude, latitude: latitude)
        let band = calculateBand(latitude: latitude)

        // Special case for Norway
        let adjustedZone = adjustZoneForNorway(zone: zone, latitude: latitude, longitude: longitude)

        let centralMeridian = Double(adjustedZone * 6 - 183)
        let lonRad = longitude * .pi / 180.0
        let latRad = latitude * .pi / 180.0
        let centralMeridianRad = centralMeridian * .pi / 180.0

        let N = a / sqrt(1.0 - e2 * sin(latRad) * sin(latRad))
        let T = tan(latRad) * tan(latRad)
        let C = (e2 / (1.0 - e2)) * cos(latRad) * cos(latRad)
        let A = (lonRad - centralMeridianRad) * cos(latRad)

        let M = a * ((1.0 - e2 / 4.0 - 3.0 * e4 / 64.0 - 5.0 * e6 / 256.0) * latRad
                     - (3.0 * e2 / 8.0 + 3.0 * e4 / 32.0 + 45.0 * e6 / 1024.0) * sin(2.0 * latRad)
                     + (15.0 * e4 / 256.0 + 45.0 * e6 / 1024.0) * sin(4.0 * latRad)
                     - (35.0 * e6 / 3072.0) * sin(6.0 * latRad))

        let easting = k0 * N * (A + (1.0 - T + C) * A * A * A / 6.0
                                + (5.0 - 18.0 * T + T * T + 72.0 * C - 58.0 * e2 / (1.0 - e2))
                                * A * A * A * A * A / 120.0) + 500000.0

        var northing = k0 * (M + N * tan(latRad) * (A * A / 2.0
                                                    + (5.0 - T + 9.0 * C + 4.0 * C * C) * A * A * A * A / 24.0
                                                    + (61.0 - 58.0 * T + T * T + 600.0 * C - 330.0 * e2 / (1.0 - e2))
                                                    * A * A * A * A * A * A / 720.0))

        // Southern hemisphere adjustment
        if latitude < 0 {
            northing += 10000000.0
        }

        return UTMCoordinate(zone: adjustedZone, band: band, easting: easting, northing: northing)
    }

    // MARK: - UTM to Lat/Lon

    /// Converts UTM coordinates to latitude and longitude.
    /// - Parameters:
    ///   - easting: The easting value in meters.
    ///   - northing: The northing value in meters.
    ///   - zone: The UTM zone number.
    ///   - band: The UTM latitude band letter.
    /// - Returns: A tuple containing the latitude and longitude in degrees.
    public static func toLatLon(easting: Double, northing: Double, zone: Int, band: Character) -> (latitude: Double, longitude: Double) {
        let centralMeridian = Double(zone * 6 - 183)
        let x = easting - 500000.0
        var y = northing

        // Southern hemisphere adjustment
        if band < "N" {
            y -= 10000000.0
        }

        let M = y / k0
        let μ = M / (a * (1.0 - e2 / 4.0 - 3.0 * e4 / 64.0 - 5.0 * e6 / 256.0))

        let φ1 = μ + (3.0 * e2 / 8.0 + 3.0 * e4 / 32.0 + 45.0 * e6 / 1024.0) * sin(2.0 * μ)
        + (15.0 * e4 / 256.0 + 45.0 * e6 / 1024.0) * sin(4.0 * μ)
        + (35.0 * e6 / 3072.0) * sin(6.0 * μ)

        let N1 = a / sqrt(1.0 - e2 * sin(φ1) * sin(φ1))
        let T1 = tan(φ1) * tan(φ1)
        let C1 = (e2 / (1.0 - e2)) * cos(φ1) * cos(φ1)
        let R1 = a * (1.0 - e2) / pow(1.0 - e2 * sin(φ1) * sin(φ1), 1.5)
        let D = x / (N1 * k0)

        let latitude = φ1 - (N1 * tan(φ1) / R1) * (D * D / 2.0
                                                   - (5.0 + 3.0 * T1 + 10.0 * C1 - 4.0 * C1 * C1 - 9.0 * e2 / (1.0 - e2))
                                                   * D * D * D * D / 24.0
                                                   + (61.0 + 90.0 * T1 + 298.0 * C1 + 45.0 * T1 * T1 - 252.0 * e2 / (1.0 - e2) - 3.0 * C1 * C1)
                                                   * D * D * D * D * D * D / 720.0)

        let longitude = (D - (1.0 + 2.0 * T1 + C1) * D * D * D / 6.0
                         + (5.0 - 2.0 * C1 + 28.0 * T1 - 3.0 * C1 * C1 + 8.0 * e2 / (1.0 - e2) + 24.0 * T1 * T1)
                         * D * D * D * D * D / 120.0) / cos(φ1)

        return (latitude: latitude * 180.0 / .pi, longitude: longitude * 180.0 / .pi + centralMeridian)
    }

    // MARK: - Zone Calculation

    private static func calculateZone(longitude: Double, latitude: Double) -> Int {
        var zone = Int((longitude + 180.0) / 6.0) + 1

        // Special cases for Norway and Svalbard
        if latitude >= 56.0 && latitude < 64.0 && longitude >= 3.0 && longitude < 12.0 {
            zone = 32
        } else if latitude >= 72.0 && latitude < 84.0 {
            if longitude >= 0.0 && longitude < 9.0 {
                zone = 31
            } else if longitude >= 9.0 && longitude < 21.0 {
                zone = 33
            } else if longitude >= 21.0 && longitude < 33.0 {
                zone = 35
            } else if longitude >= 33.0 && longitude < 42.0 {
                zone = 37
            }
        }

        return zone
    }

    private static func adjustZoneForNorway(zone: Int, latitude: Double, longitude: Double) -> Int {
        // Norway exceptions
        if zone == 31 && latitude >= 56.0 && latitude < 64.0 && longitude >= 3.0 && longitude < 6.0 {
            return 32
        }
        if zone == 32 && latitude >= 56.0 && latitude < 64.0 && longitude >= 6.0 && longitude < 12.0 {
            return 32
        }
        if zone == 33 && latitude >= 56.0 && latitude < 64.0 && longitude >= 9.0 && longitude < 12.0 {
            return 32
        }
        return zone
    }

    // MARK: - Band Calculation

    private static func calculateBand(latitude: Double) -> Character {
        let bands: [Character] = ["C", "D", "E", "F", "G", "H", "J", "K", "L", "M",
                                  "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X"]

        if latitude < -80.0 { return "A" }
        if latitude >= 84.0 { return "Z" }

        let index = Int((latitude + 80.0) / 8.0)
        return bands[min(max(index, 0), bands.count - 1)]
    }

    // MARK: - Parse UTM String

    /// Parses a UTM string into a UTMCoordinate.
    /// - Parameter value: The UTM string to parse (e.g., "18N 585628 4511322").
    /// - Returns: A UTMCoordinate struct containing the parsed values.
    /// - Throws: `ParseError` if the string format is invalid.
    public static func parseUTM(_ value: String) throws -> UTMCoordinate {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)

        // Pattern: 18N 585628 4511322 or 18 N 585628 4511322
        let pattern = #"(\d{1,2})\s*([A-Z])\s+(\d+(?:\.\d+)?)\s+(\d+(?:\.\d+)?)"#
        let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)

        guard let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: trimmed.count)) else {
            throw ParseError.invalidFormat
        }

        let zoneRange = Range(match.range(at: 1), in: trimmed)!
        let bandRange = Range(match.range(at: 2), in: trimmed)!
        let eastingRange = Range(match.range(at: 3), in: trimmed)!
        let northingRange = Range(match.range(at: 4), in: trimmed)!

        guard let zone = Int(trimmed[zoneRange]),
              let easting = Double(trimmed[eastingRange]),
              let northing = Double(trimmed[northingRange]) else {
            throw ParseError.invalidNumber
        }

        let band = trimmed[bandRange].uppercased().first!

        guard (1...60).contains(zone) else {
            throw ParseError.invalidZone
        }

        guard "CDEFGHJKLMNPQRSTUVWX".contains(band) else {
            throw ParseError.invalidBand
        }

        return UTMCoordinate(zone: zone, band: band, easting: easting, northing: northing)
    }

    /// Represents a UTM coordinate with zone, band, easting, and northing values.
    public struct UTMCoordinate {
        /// The UTM zone number (1-60).
        public let zone: Int
        /// The UTM latitude band letter.
        public let band: Character
        /// The easting value in meters.
        public let easting: Double
        /// The northing value in meters.
        public let northing: Double
    }

    enum ParseError: LocalizedError {
        case invalidFormat
        case invalidNumber
        case invalidZone
        case invalidBand

        var errorDescription: String? {
            switch self {
                case .invalidFormat:
                    String(localized: "Invalid UTM format")
                case .invalidNumber:
                    String(localized: "Invalid numeric value")
                case .invalidZone:
                    String(localized: "Invalid UTM zone (must be 1-60)")
                case .invalidBand:
                    String(localized: "Invalid UTM band letter")
            }
        }
    }
}
