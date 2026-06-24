import Foundation
import SwiftUI

@MainActor
@Observable
final class MGRSEntryManager {
  private static let zoneWidth = 2
  private static let coordinatePrecision = 5  // 1m precision.
  private static let maxZone = 60

  private(set) var zone = ""
  private(set) var band = ""
  private(set) var column = ""
  private(set) var row = ""
  private(set) var easting = ""
  private(set) var northing = ""
  private(set) var currentIndex = 0

  var inputMode: InputMode {
    if currentIndex < FieldIndex.bandIndex {
      return .zone
    }
    if currentIndex == FieldIndex.bandIndex {
      return .band
    }
    if currentIndex == FieldIndex.columnIndex {
      return .column
    }
    if currentIndex == FieldIndex.rowIndex {
      return .row
    }
    return .numeric
  }

  var validBands: [Character] {
    // Valid MGRS bands (excludes I and O)
    [
      "C", "D", "E", "F", "G", "H", "J", "K", "L", "M",
      "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X"
    ]
  }

  var validColumns: [Character] {
    // Valid MGRS column letters (excludes I and O)
    [
      "A", "B", "C", "D", "E", "F", "G", "H", "J", "K",
      "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V",
      "W", "X", "Y", "Z"
    ]
  }

  var validRows: [Character] {
    // Valid MGRS row letters (excludes I, O, and letters after V)
    [
      "A", "B", "C", "D", "E", "F", "G", "H", "J", "K",
      "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V"
    ]
  }

  var stringValue: String {
    var result = zone.padding(toLength: Self.zoneWidth, withPad: "0", startingAt: 0)
    result += band.isEmpty ? "_" : band
    result += " "  // Space after band letter
    result += column.isEmpty ? "_" : column
    result += row.isEmpty ? "_" : row
    result += " "

    result += easting.padding(toLength: Self.coordinatePrecision, withPad: "0", startingAt: 0)
    result += " "
    result += northing.padding(toLength: Self.coordinatePrecision, withPad: "0", startingAt: 0)

    return result
  }

  var attributedString: AttributedString {
    var result = AttributedString()

    for (i, char) in stringValue.enumerated() {
      var attrChar = AttributedString(String(char))
      if i == currentIndex {
        attrChar.foregroundColor = Color(.systemBackground)
        attrChar.backgroundColor = .accent
      } else if char == "_" {
        attrChar.foregroundColor = .gray
      }
      result.append(attrChar)
    }

    return result
  }

  var isValid: Bool {
    // Build MGRS string for validation
    let mgrsString = buildMGRSString()
    return MGRSHelper.validate(mgrsString)
  }

  init(coordinate: Coordinate) {
    if let mgrs = MGRSHelper.fromCoordinate(coordinate, precision: .oneM) {
      // Parse the MGRS string to extract components
      parseMGRS(mgrs)
    }
  }

  private func parseMGRS(_ mgrs: String) {
    let cleaned = mgrs.replacingOccurrences(of: " ", with: "")
    var index = cleaned.startIndex

    // Extract zone (1-2 digits)
    var zoneStr = ""
    while index < cleaned.endIndex && cleaned[index].isNumber {
      zoneStr.append(cleaned[index])
      index = cleaned.index(after: index)
    }
    zone = zoneStr

    // Extract band letter
    if index < cleaned.endIndex && cleaned[index].isLetter {
      band = String(cleaned[index])
      index = cleaned.index(after: index)
    }

    // Extract column letter
    if index < cleaned.endIndex && cleaned[index].isLetter {
      column = String(cleaned[index])
      index = cleaned.index(after: index)
    }

    // Extract row letter
    if index < cleaned.endIndex && cleaned[index].isLetter {
      row = String(cleaned[index])
      index = cleaned.index(after: index)
    }

    // Remaining are coordinates
    let remaining = String(cleaned[index...])
    if !remaining.isEmpty {
      let halfLength = remaining.count / 2
      easting = String(remaining.prefix(halfLength))
      northing = String(remaining.suffix(halfLength))
    }
  }

  private func buildMGRSString() -> String {
    var result = zone + band + column + row

    // Ensure easting and northing have equal length
    let maxLen = max(easting.count, northing.count)
    if maxLen > 0 {
      let paddedEasting = easting.padding(toLength: maxLen, withPad: "0", startingAt: 0)
      let paddedNorthing = northing.padding(toLength: maxLen, withPad: "0", startingAt: 0)
      result += paddedEasting + paddedNorthing
    }

    return result
  }

  func add(_ character: Character) {
    if currentIndex < FieldIndex.bandIndex {
      // Zone input (1-60).
      if character.isNumber {
        if currentIndex == FieldIndex.zoneFirst {
          zone = String(character)
        } else {
          zone += String(character)
          if let zoneNum = Int(zone), zoneNum > Self.maxZone {
            zone = String(character)  // Reset to single digit.
          }
        }
      }
    } else if currentIndex == FieldIndex.bandIndex {
      if validBands.contains(character) {
        band = String(character)
      }
    } else if currentIndex == FieldIndex.columnIndex {
      if validColumns.contains(character) {
        column = String(character)
      }
    } else if currentIndex == FieldIndex.rowIndex {
      if validRows.contains(character) {
        row = String(character)
      }
    } else if (FieldIndex.eastingStart..<FieldIndex.eastingEnd).contains(currentIndex) {
      if character.isNumber {
        easting = replacingDigit(
          in: easting,
          at: currentIndex - FieldIndex.eastingStart,
          with: character
        )
      }
    } else if (FieldIndex.northingStart..<FieldIndex.northingEnd).contains(currentIndex) {
      if character.isNumber {
        northing = replacingDigit(
          in: northing,
          at: currentIndex - FieldIndex.northingStart,
          with: character
        )
      }
    }

    advance()
  }

  func backspace() {
    retreat()

    if currentIndex < FieldIndex.bandIndex {
      if currentIndex == FieldIndex.zoneFirst && !zone.isEmpty {
        zone = String(zone.dropFirst())
      } else if currentIndex == FieldIndex.zoneFirst + 1 && zone.count > 1 {
        zone = String(zone.dropLast())
      }
    } else if currentIndex == FieldIndex.bandIndex {
      band = ""
    } else if currentIndex == FieldIndex.columnIndex {
      column = ""
    } else if currentIndex == FieldIndex.rowIndex {
      row = ""
    } else if (FieldIndex.eastingStart..<FieldIndex.eastingEnd).contains(currentIndex) {
      easting = clearingDigit(in: easting, at: currentIndex - FieldIndex.eastingStart)
    } else if (FieldIndex.northingStart..<FieldIndex.northingEnd).contains(currentIndex) {
      northing = clearingDigit(in: northing, at: currentIndex - FieldIndex.northingStart)
    }
  }

  func setIndex(_ index: Int) {
    if index < stringValue.count {
      currentIndex = index
      if isSpaceIndex(currentIndex) {
        currentIndex += 1
      }
    }
  }

  func coordinate() -> Coordinate? {
    guard isValid else { return nil }
    let mgrsString = buildMGRSString()
    return MGRSHelper.toCoordinate(mgrsString)
  }

  private func advance() {
    currentIndex += 1
    if isSpaceIndex(currentIndex) {
      currentIndex += 1
    }
    if currentIndex >= FieldIndex.northingEnd {
      currentIndex = 0
    }
  }

  private func retreat() {
    currentIndex -= 1
    if isSpaceIndex(currentIndex) {
      currentIndex -= 1
    }
    if currentIndex < 0 {
      currentIndex = FieldIndex.northingEnd - 1
    }
  }

  private func isSpaceIndex(_ index: Int) -> Bool {
    index == FieldIndex.firstSpace || index == FieldIndex.secondSpace
      || index == FieldIndex.thirdSpace
  }

  private func replacingDigit(in field: String, at position: Int, with character: Character)
    -> String
  {
    if position < field.count {
      var chars = Array(field)
      chars[position] = character
      return String(chars)
    }
    return field + String(character)
  }

  private func clearingDigit(in field: String, at position: Int) -> String {
    guard position < field.count else { return field }
    var chars = Array(field)
    chars[position] = "0"
    return String(chars)
  }

  enum InputMode {
    case zone
    case band
    case column
    case row
    case numeric
  }

  /// Cursor positions within the formatted MGRS string. Spaces sit at the gaps
  /// between these field ranges and are skipped while navigating.
  private enum FieldIndex {
    static let zoneFirst = 0
    static let bandIndex = 2
    static let columnIndex = 4  // Index 3 is a space.
    static let rowIndex = 5
    static let firstSpace = 3
    static let secondSpace = 6
    static let thirdSpace = 12
    static let eastingStart = 7
    static let eastingEnd = 12  // Exclusive.
    static let northingStart = 13
    static let northingEnd = 18  // Exclusive.
  }
}
