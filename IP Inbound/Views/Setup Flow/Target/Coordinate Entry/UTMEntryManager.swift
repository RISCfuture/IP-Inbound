import Foundation
import SwiftGeographic
import SwiftUI

@MainActor
@Observable
final class UTMEntryManager {
  private(set) var zone: String = ""
  private(set) var band: String = ""
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
    var result = zone.padding(toLength: 2, withPad: "0", startingAt: 0)
    result += band.isEmpty ? "_" : band
    result += " "
    result += easting.padding(toLength: 6, withPad: "0", startingAt: 0)
    result += " "
    result += northing.padding(toLength: 7, withPad: "0", startingAt: 0)
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
    guard let zoneNum = Int(zone), (1...60).contains(zoneNum) else {
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
    if currentIndex < 2 {
      // Zone input (0-60)
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
    } else if currentIndex >= 4 && currentIndex < 10 {
      // Easting input (6 digits)
      if character.isNumber {
        let position = currentIndex - 4
        if position < easting.count {
          var chars = Array(easting)
          chars[position] = character
          easting = String(chars)
        } else {
          easting += String(character)
        }
      }
    } else if currentIndex >= 11 && currentIndex < 18 {
      // Northing input (7 digits)
      if character.isNumber {
        let position = currentIndex - 11
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
    } else if currentIndex >= 4 && currentIndex < 10 {
      // Easting
      let position = currentIndex - 4
      if position < easting.count {
        var chars = Array(easting)
        chars[position] = "0"
        easting = String(chars)
      }
    } else if currentIndex >= 11 && currentIndex < 18 {
      // Northing
      let position = currentIndex - 11
      if position < northing.count {
        var chars = Array(northing)
        chars[position] = "0"
        northing = String(chars)
      }
    }
  }

  func advance() {
    currentIndex += 1
    // Skip spaces
    if currentIndex == 3 || currentIndex == 10 {
      currentIndex += 1
    }
    if currentIndex >= 18 {
      currentIndex = 0
    }
  }

  func retreat() {
    currentIndex -= 1
    // Skip spaces
    if currentIndex == 3 || currentIndex == 10 {
      currentIndex -= 1
    }
    if currentIndex < 0 {
      currentIndex = 17
    }
  }

  func setIndex(_ index: Int) {
    if index < stringValue.count {
      currentIndex = index
      // Skip spaces
      if currentIndex == 3 || currentIndex == 10 {
        currentIndex += 1
      }
    }
  }

  func getCoordinate() -> Coordinate? {
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

  enum InputMode {
    case zone
    case band
    case numeric
  }
}
