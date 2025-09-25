import Foundation
import SwiftUI

@MainActor
@Observable
final class MGRSEntryManager {
  private(set) var zone: String = ""
  private(set) var band: String = ""
  private(set) var column: String = ""
  private(set) var row: String = ""
  private(set) var easting: String = ""
  private(set) var northing: String = ""
  private(set) var currentIndex = 0

  var inputMode: InputMode {
    if currentIndex < 2 {
      return .zone
    }
    if currentIndex == 2 {
      return .band
    }
    if currentIndex == 4 {  // Account for space at index 3
      return .column
    }
    if currentIndex == 5 {
      return .row
    }
    return .numeric
  }

  var validBands: [Character] {
    // Valid MGRS bands (excludes I and O)
    [
      "C", "D", "E", "F", "G", "H", "J", "K", "L", "M",
      "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X",
    ]
  }

  var validColumns: [Character] {
    // Valid MGRS column letters (excludes I and O)
    [
      "A", "B", "C", "D", "E", "F", "G", "H", "J", "K",
      "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V",
      "W", "X", "Y", "Z",
    ]
  }

  var validRows: [Character] {
    // Valid MGRS row letters (excludes I, O, and letters after V)
    [
      "A", "B", "C", "D", "E", "F", "G", "H", "J", "K",
      "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V",
    ]
  }

  var stringValue: String {
    var result = zone.padding(toLength: 2, withPad: "0", startingAt: 0)
    result += band.isEmpty ? "_" : band
    result += " "  // Space after band letter
    result += column.isEmpty ? "_" : column
    result += row.isEmpty ? "_" : row
    result += " "

    // Show easting and northing with appropriate precision
    let precision = 6  // Default to 1m precision
    result += easting.padding(toLength: precision, withPad: "0", startingAt: 0)
    result += " "
    result += northing.padding(toLength: precision, withPad: "0", startingAt: 0)

    return result
  }

  var attributedString: AttributedString {
    var result = AttributedString()

    for (i, char) in stringValue.enumerated() {
      var attrChar = AttributedString(String(char))
      if i == currentIndex {
        attrChar.foregroundColor = UIColor.systemBackground
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

  init(mgrsString: String) {
    // Initialize directly from an MGRS string (preserves user input)
    parseMGRS(mgrsString)
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
    if currentIndex < 2 {
      // Zone input (1-60)
      if character.isNumber {
        if currentIndex == 0 {
          zone = String(character)
        } else {
          zone += String(character)
          // Validate zone range
          if let zoneNum = Int(zone), zoneNum > 60 {
            zone = String(character)  // Reset to single digit
          }
        }
      }
    } else if currentIndex == 2 {
      // Band input
      if validBands.contains(character) {
        band = String(character)
      }
    } else if currentIndex == 4 {  // Account for space at index 3
      // Column input
      if validColumns.contains(character) {
        column = String(character)
      }
    } else if currentIndex == 5 {
      // Row input
      if validRows.contains(character) {
        row = String(character)
      }
    } else if currentIndex >= 7 && currentIndex < 12 {  // Account for spaces
      // Easting input (up to 5 digits)
      if character.isNumber {
        let position = currentIndex - 7
        if position < easting.count {
          var chars = Array(easting)
          chars[position] = character
          easting = String(chars)
        } else {
          easting += String(character)
        }
      }
    } else if currentIndex >= 13 && currentIndex < 18 {  // Account for spaces
      // Northing input (up to 5 digits)
      if character.isNumber {
        let position = currentIndex - 13
        if position < northing.count {
          var chars = Array(northing)
          chars[position] = character
          northing = String(chars)
        } else {
          northing += String(character)
        }
      }
    }

    advance()
  }

  func backspace() {
    retreat()

    if currentIndex < 2 {
      // Zone
      if currentIndex == 0 && !zone.isEmpty {
        zone = String(zone.dropFirst())
      } else if currentIndex == 1 && zone.count > 1 {
        zone = String(zone.dropLast())
      }
    } else if currentIndex == 2 {
      // Band
      band = ""
    } else if currentIndex == 4 {  // Account for space at index 3
      // Column
      column = ""
    } else if currentIndex == 5 {
      // Row
      row = ""
    } else if currentIndex >= 7 && currentIndex < 12 {  // Account for spaces
      // Easting
      let position = currentIndex - 7
      if position < easting.count {
        var chars = Array(easting)
        chars[position] = "0"
        easting = String(chars)
      }
    } else if currentIndex >= 13 && currentIndex < 18 {  // Account for spaces
      // Northing
      let position = currentIndex - 13
      if position < northing.count {
        var chars = Array(northing)
        chars[position] = "0"
        northing = String(chars)
      }
    }
  }

  private func advance() {
    currentIndex += 1
    // Skip spaces (after band at 3, after row at 6, after easting at 12)
    if currentIndex == 3 || currentIndex == 6 || currentIndex == 12 {
      currentIndex += 1
    }
    if currentIndex >= 18 {
      currentIndex = 0
    }
  }

  private func retreat() {
    currentIndex -= 1
    // Skip spaces (after band at 3, after row at 6, after easting at 12)
    if currentIndex == 3 || currentIndex == 6 || currentIndex == 12 {
      currentIndex -= 1
    }
    if currentIndex < 0 {
      currentIndex = 17
    }
  }

  func setIndex(_ index: Int) {
    if index < stringValue.count {
      currentIndex = index
      // Skip spaces (after band at 3, after row at 6, after easting at 12)
      if currentIndex == 3 || currentIndex == 6 || currentIndex == 12 {
        currentIndex += 1
      }
    }
  }

  func getCoordinate() -> Coordinate? {
    guard isValid else { return nil }
    let mgrsString = buildMGRSString()
    return MGRSHelper.toCoordinate(mgrsString)
  }

  enum InputMode {
    case zone
    case band
    case column
    case row
    case numeric
  }
}
