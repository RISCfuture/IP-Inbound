import Foundation
import SwiftGeographic
import SwiftUI

@MainActor
@Observable
final class UTMEntryManager {
  private static let zoneWidth = 2
  private static let eastingWidth = 6
  private static let northingWidth = 7
  private static let maxZone = 60

  private(set) var zone = ""
  private(set) var band = ""
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
    return .numeric
  }

  var validBands: [Character] {
    // Valid UTM bands
    [
      "C", "D", "E", "F", "G", "H", "J", "K", "L", "M",
      "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X"
    ]
  }

  var stringValue: String {
    var result = zone.padding(toLength: Self.zoneWidth, withPad: "0", startingAt: 0)
    result += band.isEmpty ? "_" : band
    result += " "
    result += easting.padding(toLength: Self.eastingWidth, withPad: "0", startingAt: 0)
    result += " "
    result += northing.padding(toLength: Self.northingWidth, withPad: "0", startingAt: 0)
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
    guard let zoneNum = Int(zone), (1...Self.maxZone).contains(zoneNum) else {
      return false
    }
    guard !band.isEmpty && validBands.contains(Character(band)) else {
      return false
    }
    guard let eastingNum = Int(easting), eastingNum > 0 else {
      return false
    }
    guard let northingNum = Int(northing), northingNum > 0 else {
      return false
    }
    return true
  }

  init(coordinate: Coordinate) {
    guard
      let geo = try? GeographicCoordinate(
        latitude: coordinate.latitudeDeg,
        longitude: coordinate.longitudeDeg
      ),
      let utm = try? geo.utm
    else { return }

    zone = String(utm.zone)
    band = String(coordinate.utmBand)
    easting = String(Int(utm.easting))
    northing = String(Int(utm.northing))
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

    let hemisphere: Hemisphere = Character(band) < "N" ? .south : .north
    guard
      let utmCoord = try? SwiftGeographic.UTMCoordinate(
        zone: Int(zone) ?? 0,
        hemisphere: hemisphere,
        easting: Double(easting) ?? 0,
        northing: Double(northing) ?? 0
      ),
      let geo = try? utmCoord.geographic
    else { return nil }

    return Coordinate(latitude: geo.latitude, longitude: geo.longitude)
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
    case numeric
  }

  /// Cursor positions within the formatted UTM string. Spaces sit at the gaps
  /// between these field ranges and are skipped while navigating.
  private enum FieldIndex {
    static let zoneFirst = 0
    static let bandIndex = 2
    static let firstSpace = 3
    static let eastingStart = 4
    static let eastingEnd = 10  // Exclusive.
    static let secondSpace = 10
    static let northingStart = 11
    static let northingEnd = 18  // Exclusive.
  }
}
