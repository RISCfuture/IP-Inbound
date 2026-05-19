import CoreLocation
import Foundation
import SwiftGeographic

enum MGRSHelper {
  static func fromCoordinate(_ coordinate: Coordinate, precision: Precision = .oneM) -> String? {
    guard
      let geo = try? GeographicCoordinate(
        latitude: coordinate.latitudeDeg,
        longitude: coordinate.longitudeDeg
      ),
      let mgrs = try? geo.mgrs(precision: precision.mgrsPrecision)
    else { return nil }

    switch precision {
      case .gridZone:
        return mgrs.gridZone
      case .hundredKm:
        return "\(mgrs.gridZone) \(mgrs.squareIdentifier)"
      default:
        return format(mgrs.gridReference, withSpaces: true)
    }
  }

  static func toCoordinate(_ mgrsString: String) -> Coordinate? {
    let cleaned =
      mgrsString
      .uppercased()
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "-", with: "")

    guard isSafeToParseForDisplay(cleaned) else {
      return nil
    }

    guard let mgrs = try? MGRSCoordinate(string: cleaned),
      let geo = try? mgrs.geographic
    else { return nil }

    return Coordinate(latitude: geo.latitude, longitude: geo.longitude)
  }

  static func validate(_ mgrsString: String) -> Bool {
    let cleaned =
      mgrsString
      .uppercased()
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "-", with: "")

    return isSafeToParseForDisplay(cleaned)
  }

  // More thorough validation to prevent MGRS.parse from crashing
  private static func isSafeToParseForDisplay(_ cleaned: String) -> Bool {
    // Check minimum length
    guard cleaned.count >= 3 else {
      return false
    }

    // Extract components
    var index = cleaned.startIndex
    var zoneStr = ""

    // Zone number (1-60)
    while index < cleaned.endIndex && cleaned[index].isNumber {
      zoneStr.append(cleaned[index])
      index = cleaned.index(after: index)
    }

    guard let zone = Int(zoneStr), (1...60).contains(zone) else {
      return false
    }

    // Band letter
    guard index < cleaned.endIndex else { return false }
    let band = cleaned[index]
    guard "CDEFGHJKLMNPQRSTUVWX".contains(band) else {
      return false
    }
    index = cleaned.index(after: index)

    // If we only have zone and band, that's valid
    if index >= cleaned.endIndex {
      return true
    }

    // 100km square identification (2 letters)
    if index < cleaned.endIndex {
      let col = cleaned[index]
      guard col.isLetter && "ABCDEFGHJKLMNPQRSTUVWXYZ".contains(col) else {
        return false
      }
      index = cleaned.index(after: index)

      if index < cleaned.endIndex {
        let row = cleaned[index]
        guard row.isLetter && "ABCDEFGHJKLMNPQRSTUV".contains(row) else {
          return false
        }
        index = cleaned.index(after: index)
      } else {
        // Only one letter of the square, invalid
        return false
      }
    }

    // Remaining should be coordinates (even number of digits)
    if index < cleaned.endIndex {
      let remaining = String(cleaned[index...])
      guard remaining.allSatisfy(\.isNumber) else {
        return false
      }
      // Must be even number (equal easting and northing)
      guard remaining.count.isMultiple(of: 2) else {
        return false
      }
      // Maximum 10 digits total (5 for easting, 5 for northing)
      guard remaining.count <= 10 else {
        return false
      }
    }

    return true
  }

  static func format(_ mgrsString: String, withSpaces: Bool = true) -> String? {
    // Clean and validate
    let cleaned =
      mgrsString
      .uppercased()
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "-", with: "")

    guard validate(cleaned) else {
      return nil
    }

    // Parse components
    // MGRS format: [Zone][Band][Column][Row][Easting][Northing]
    // Zone: 1-2 digits, Band: 1 letter, Column: 1 letter, Row: 1 letter
    // Easting/Northing: 1-5 digits each (must be equal length)

    var index = cleaned.startIndex
    var result = ""

    // Extract zone (1-2 digits)
    while index < cleaned.endIndex && cleaned[index].isNumber {
      result.append(cleaned[index])
      index = cleaned.index(after: index)
    }

    // Extract band letter
    if index < cleaned.endIndex && cleaned[index].isLetter {
      result.append(cleaned[index])
      index = cleaned.index(after: index)
    }

    // Extract column and row letters (100km square)
    if index < cleaned.endIndex && cleaned[index].isLetter {
      if withSpaces {
        result.append(" ")
      }
      result.append(cleaned[index])
      index = cleaned.index(after: index)
    }

    if index < cleaned.endIndex && cleaned[index].isLetter {
      result.append(cleaned[index])
      index = cleaned.index(after: index)
    }

    // Remaining characters should be coordinates (even number of digits)
    let remaining = String(cleaned[index...])
    if !remaining.isEmpty {
      let halfLength = remaining.count / 2
      let easting = String(remaining.prefix(halfLength))
      let northing = String(remaining.suffix(halfLength))

      if withSpaces {
        result.append(" \(easting) \(northing)")
      } else {
        result.append("\(easting)\(northing)")
      }
    }

    return result
  }

  enum Precision {
    case gridZone  // Grid Zone only (e.g., "33X")
    case hundredKm  // 100km square (e.g., "33X VG")
    case tenKm  // 10km precision (e.g., "33X VG 74")
    case oneKm  // 1km precision (e.g., "33X VG 74 59")
    case hundredM  // 100m precision (e.g., "33X VG 745 593")
    case tenM  // 10m precision (e.g., "33X VG 7459 5936")
    case oneM  // 1m precision (e.g., "33X VG 74594 59364")

    var mgrsPrecision: MGRSPrecision {
      switch self {
        case .gridZone, .hundredKm: .hundredKilometer
        case .tenKm: .tenKilometer
        case .oneKm: .oneKilometer
        case .hundredM: .hundredMeter
        case .tenM: .tenMeter
        case .oneM: .oneMeter
      }
    }
  }
}
