import CoreLocation
import Defaults
import Foundation
import Grid
import MGRS

// MARK: - Coordinate Format

public enum CoordinateFormat: String, CaseIterable, Sendable, Codable, Defaults.Serializable {
  case decimalDegrees = "dd"
  case degreesDecimalMinutes = "ddm"
  case degreesMinutesSeconds = "dms"
  case utm = "utm"
  case mgrs = "mgrs"
}

// MARK: - Format Style

public struct CoordinateFormatStyle: FormatStyle, Codable, Equatable, Hashable {
  public typealias FormatInput = Coordinate
  public typealias FormatOutput = String

  public let format: CoordinateFormat
  public let precision: Precision

  public init(format: CoordinateFormat, precision: Precision = .standard) {
    self.format = format
    self.precision = precision
  }

  public func format(_ value: Coordinate) -> String {
    switch format {
      case .decimalDegrees:
        return formatDecimalDegrees(value)
      case .degreesDecimalMinutes:
        return formatDegreesDecimalMinutes(value)
      case .degreesMinutesSeconds:
        return formatDegreesMinutesSeconds(value)
      case .utm:
        return formatUTM(value)
      case .mgrs:
        return formatMGRS(value)
    }
  }

  // MARK: - Decimal Degrees

  private func formatDecimalDegrees(_ coordinate: Coordinate) -> String {
    let lat = abs(coordinate.latitudeDeg)
    let lon = abs(coordinate.longitudeDeg)
    let northing =
      coordinate.latitudeDeg >= 0
      ? String(localized: "N", comment: "cardinal direction")
      : String(localized: "S", comment: "cardinal direction")
    let easting =
      coordinate.longitudeDeg >= 0
      ? String(localized: "E", comment: "cardinal direction")
      : String(localized: "W", comment: "cardinal direction")

    return String(
      localized:
        "\(northing) \(lat, format: precision.degreeDecimalFormat)°\n\(easting) \(lon, format: precision.degreeDecimalFormat)°"
    )
  }

  // MARK: - Degrees Decimal Minutes

  private func formatDegreesDecimalMinutes(_ coordinate: Coordinate) -> String {
    let lat = abs(coordinate.latitudeDeg)
    let lon = abs(coordinate.longitudeDeg)

    let latDegrees = Int(lat)
    let latMinutes = (lat - Double(latDegrees)) * 60.0

    let lonDegrees = Int(lon)
    let lonMinutes = (lon - Double(lonDegrees)) * 60.0

    let northing =
      coordinate.latitudeDeg >= 0
      ? String(localized: "N", comment: "cardinal direction")
      : String(localized: "S", comment: "cardinal direction")
    let easting =
      coordinate.longitudeDeg >= 0
      ? String(localized: "E", comment: "cardinal direction")
      : String(localized: "W", comment: "cardinal direction")

    return String(
      localized:
        "\(northing) \(latDegrees, format: precision.intFormat)° \(latMinutes, format: precision.minuteDecimalFormat)′\n\(easting) \(lonDegrees, format: precision.intFormat)° \(lonMinutes, format: precision.minuteDecimalFormat)′"
    )
  }

  // MARK: - Degrees Minutes Seconds

  private func formatDegreesMinutesSeconds(_ coordinate: Coordinate) -> String {
    let lat = abs(coordinate.latitudeDeg)
    let lon = abs(coordinate.longitudeDeg)

    let latDegrees = Int(lat)
    let latMinutesDecimal = (lat - Double(latDegrees)) * 60.0
    let latMinutes = Int(latMinutesDecimal)
    let latSeconds = (latMinutesDecimal - Double(latMinutes)) * 60.0

    let lonDegrees = Int(lon)
    let lonMinutesDecimal = (lon - Double(lonDegrees)) * 60.0
    let lonMinutes = Int(lonMinutesDecimal)
    let lonSeconds = (lonMinutesDecimal - Double(lonMinutes)) * 60.0

    let northing =
      coordinate.latitudeDeg >= 0
      ? String(localized: "N", comment: "cardinal direction")
      : String(localized: "S", comment: "cardinal direction")
    let easting =
      coordinate.longitudeDeg >= 0
      ? String(localized: "E", comment: "cardinal direction")
      : String(localized: "W", comment: "cardinal direction")

    return String(
      localized:
        "\(northing) \(latDegrees, format: precision.intFormat)° \(latMinutes, format: precision.intFormat)′ \(latSeconds, format: precision.secondDecimalFormat)″\n\(easting) \(lonDegrees, format: precision.intFormat)° \(lonMinutes, format: precision.intFormat)′ \(lonSeconds, format: precision.secondDecimalFormat)″"
    )
  }

  // MARK: - UTM

  private func formatUTM(_ coordinate: Coordinate) -> String {
    let utm = UTMConverter.fromLatLon(
      latitude: coordinate.latitudeDeg,
      longitude: coordinate.longitudeDeg
    )
    let easting = Int(utm.easting)
    let northing = Int(utm.northing)

    return "\(utm.zone)\(utm.band) \(easting) \(northing)"
  }

  // MARK: - MGRS

  private func formatMGRS(_ coordinate: Coordinate) -> String {
    // Use the NGA MGRS library through our helper
    MGRSHelper.fromCoordinate(coordinate, precision: .oneM) ?? ""
  }

  public struct Precision: Codable, Equatable, Hashable, Sendable {
    public static let standard = Self(degrees: 5, minutes: 3, seconds: 0)
    public static let high = Self(degrees: 7, minutes: 5, seconds: 2)

    public let degrees: Int
    public let minutes: Int
    public let seconds: Int

    var intFormat: IntegerFormatStyle<Int> { .number }

    var degreeDecimalFormat: FloatingPointFormatStyle<Double> {
      .number.precision(.fractionLength(degrees))
    }

    var minuteDecimalFormat: FloatingPointFormatStyle<Double> {
      .number.precision(.fractionLength(minutes))
    }

    var secondDecimalFormat: FloatingPointFormatStyle<Double> {
      .number.precision(.fractionLength(seconds))
    }

    public init(degrees: Int = 5, minutes: Int = 3, seconds: Int = 0) {
      self.degrees = degrees
      self.minutes = minutes
      self.seconds = seconds
    }
  }
}

// MARK: - Parse Strategy

public struct CoordinateParseStrategy: ParseStrategy {
  public let format: CoordinateFormat

  public init(format: CoordinateFormat) {
    self.format = format
  }

  public func parse(_ value: String) throws -> Coordinate {
    switch format {
      case .decimalDegrees:
        return try parseDecimalDegrees(value)
      case .degreesDecimalMinutes:
        return try parseDegreesDecimalMinutes(value)
      case .degreesMinutesSeconds:
        return try parseDegreesMinutesSeconds(value)
      case .utm:
        return try parseUTM(value)
      case .mgrs:
        return try parseMGRS(value)
    }
  }

  private func parseDecimalDegrees(_ value: String) throws -> Coordinate {
    // Pattern: N 12.34567° E 123.45678°
    let pattern = #"([NS])\s*([\d.]+)°?\s*([EW])\s*([\d.]+)°?"#
    let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)

    guard let match = regex.firstMatch(in: value, range: NSRange(location: 0, length: value.count))
    else {
      throw ParseError.invalidFormat
    }

    let nsRange = Range(match.range(at: 1), in: value)!
    let latRange = Range(match.range(at: 2), in: value)!
    let ewRange = Range(match.range(at: 3), in: value)!
    let lonRange = Range(match.range(at: 4), in: value)!

    guard let lat = Double(value[latRange]),
      let lon = Double(value[lonRange])
    else {
      throw ParseError.invalidNumber
    }

    let latSign = value[nsRange].uppercased() == "N" ? 1.0 : -1.0
    let lonSign = value[ewRange].uppercased() == "E" ? 1.0 : -1.0

    return Coordinate(latitude: lat * latSign, longitude: lon * lonSign)
  }

  private func parseDegreesDecimalMinutes(_ value: String) throws -> Coordinate {
    // Pattern: N 12° 34.567′ E 123° 45.678′
    let pattern = #"([NS])\s*(\d+)°?\s*([\d.]+)[′']?\s*([EW])\s*(\d+)°?\s*([\d.]+)[′']?"#
    let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)

    guard let match = regex.firstMatch(in: value, range: NSRange(location: 0, length: value.count))
    else {
      throw ParseError.invalidFormat
    }

    let nsRange = Range(match.range(at: 1), in: value)!
    let latDegRange = Range(match.range(at: 2), in: value)!
    let latMinRange = Range(match.range(at: 3), in: value)!
    let ewRange = Range(match.range(at: 4), in: value)!
    let lonDegRange = Range(match.range(at: 5), in: value)!
    let lonMinRange = Range(match.range(at: 6), in: value)!

    guard let latDeg = Double(value[latDegRange]),
      let latMin = Double(value[latMinRange]),
      let lonDeg = Double(value[lonDegRange]),
      let lonMin = Double(value[lonMinRange])
    else {
      throw ParseError.invalidNumber
    }

    let latSign = value[nsRange].uppercased() == "N" ? 1.0 : -1.0
    let lonSign = value[ewRange].uppercased() == "E" ? 1.0 : -1.0

    let lat = (latDeg + latMin / 60.0) * latSign
    let lon = (lonDeg + lonMin / 60.0) * lonSign

    return Coordinate(latitude: lat, longitude: lon)
  }

  private func parseDegreesMinutesSeconds(_ value: String) throws -> Coordinate {
    // Pattern: N 12° 34′ 56.78″ E 123° 45′ 67.89″
    let pattern =
      #"([NS])\s*(\d+)°?\s*(\d+)[′']?\s*([\d.]+)[″"]?\s*([EW])\s*(\d+)°?\s*(\d+)[′']?\s*([\d.]+)[″"]?"#
    let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)

    guard let match = regex.firstMatch(in: value, range: NSRange(location: 0, length: value.count))
    else {
      throw ParseError.invalidFormat
    }

    let nsRange = Range(match.range(at: 1), in: value)!
    let latDegRange = Range(match.range(at: 2), in: value)!
    let latMinRange = Range(match.range(at: 3), in: value)!
    let latSecRange = Range(match.range(at: 4), in: value)!
    let ewRange = Range(match.range(at: 5), in: value)!
    let lonDegRange = Range(match.range(at: 6), in: value)!
    let lonMinRange = Range(match.range(at: 7), in: value)!
    let lonSecRange = Range(match.range(at: 8), in: value)!

    guard let latDeg = Double(value[latDegRange]),
      let latMin = Double(value[latMinRange]),
      let latSec = Double(value[latSecRange]),
      let lonDeg = Double(value[lonDegRange]),
      let lonMin = Double(value[lonMinRange]),
      let lonSec = Double(value[lonSecRange])
    else {
      throw ParseError.invalidNumber
    }

    let latSign = value[nsRange].uppercased() == "N" ? 1.0 : -1.0
    let lonSign = value[ewRange].uppercased() == "E" ? 1.0 : -1.0

    let lat = (latDeg + latMin / 60.0 + latSec / 3600.0) * latSign
    let lon = (lonDeg + lonMin / 60.0 + lonSec / 3600.0) * lonSign

    return Coordinate(latitude: lat, longitude: lon)
  }

  private func parseUTM(_ value: String) throws -> Coordinate {
    let utm = try UTMConverter.parseUTM(value)
    let (lat, lon) = UTMConverter.toLatLon(
      easting: utm.easting,
      northing: utm.northing,
      zone: utm.zone,
      band: utm.band
    )

    return Coordinate(latitude: lat, longitude: lon)
  }

  private func parseMGRS(_ value: String) throws -> Coordinate {
    guard let coordinate = MGRSHelper.toCoordinate(value) else {
      throw ParseError.invalidFormat
    }
    return coordinate
  }

  enum ParseError: LocalizedError {
    case invalidFormat
    case invalidNumber

    var errorDescription: String? {
      switch self {
        case .invalidFormat:
          String(
            localized: "coordinate.parse.error.format",
            defaultValue: "Invalid coordinate format"
          )
        case .invalidNumber:
          String(localized: "coordinate.parse.error.number", defaultValue: "Invalid numeric value")
      }
    }
  }
}

// MARK: - Extensions

extension Coordinate {
  /// Initializes a coordinate from a string representation.
  /// - Parameters:
  ///   - string: The string representation of the coordinate.
  ///   - format: The coordinate format used in the string.
  /// - Throws: `CoordinateParseStrategy.ParseError` if the string cannot be parsed.
  public init(_ string: String, format: CoordinateFormat) throws {
    let parser = CoordinateParseStrategy(format: format)
    self = try parser.parse(string)
  }

  /// Formats the coordinate using the specified style.
  /// - Parameter style: The format style to use for formatting.
  /// - Returns: A formatted string representation of the coordinate.
  public func formatted(_ style: CoordinateFormatStyle) -> String {
    style.format(self)
  }
}

extension FormatStyle where Self == CoordinateFormatStyle {
  /// Creates a coordinate format style.
  /// - Parameters:
  ///   - format: The coordinate format to use.
  ///   - precision: The precision settings for formatting.
  /// - Returns: A configured coordinate format style.
  public static func coordinate(
    _ format: CoordinateFormat,
    precision: CoordinateFormatStyle.Precision = .standard
  ) -> CoordinateFormatStyle {
    CoordinateFormatStyle(format: format, precision: precision)
  }
}
