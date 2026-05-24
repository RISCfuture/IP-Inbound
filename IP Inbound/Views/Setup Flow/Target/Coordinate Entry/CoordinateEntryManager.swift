import Defaults
import DefaultsMacros
import Foundation
import SwiftUI

extension Double {
  fileprivate var degreesDecimal: Double { magnitude }
  fileprivate var degrees: Int { Int(degreesDecimal) }
  fileprivate var minutesDecimal: Double { degreesDecimal.subunitPortion(divisor: 60) }
  fileprivate var minutes: Int { Int(minutesDecimal) }
  fileprivate var secondsDecimal: Double {
    degreesDecimal.subunitPortion(divisor: 3600, modulus: 60)
  }
  fileprivate var seconds: Int { Int(secondsDecimal.rounded()) }

  fileprivate func subunitPortion(divisor: Int, modulus: Int? = nil) -> Double {
    let modulus = modulus ?? divisor
    let scaled = self * Double(divisor)
    return scaled.truncatingRemainder(dividingBy: Double(modulus))
  }
}

@MainActor
@Observable
final class CoordinateEntryManager {
  var coordinate: Coordinate

  @ObservableDefault(.coordinateFormat)
  @ObservationIgnored var format: CoordinateFormat

  private(set) var currentIndex = 0
  private var indexInString: String.Index { indexInString(currentIndex) }
  @MainActor private let utmFormatter = CoordinateFormatStyle(format: .utm)
  private var formatChangeObserver: Task<Void, Never>?

  var digitType: DigitType { digitType(for: currentIndex) }

  private var latitude: Double { coordinate.latitudeDeg }
  private var longitude: Double { coordinate.longitudeDeg }
  private var northing: String { coordinate.latitudeDeg.sign == .minus ? "S" : "N" }
  private var easting: String { coordinate.longitudeDeg.sign == .minus ? "W" : "E" }

  // `String(format:)` is used here so each field is zero-padded to a fixed width,
  // keeping the monospaced digits vertically aligned and the cursor positions stable.
  var stringValue: String {
    switch format {
      case .decimalDegrees:
        return String(
          format: "%@ %08.5f°\n%@ %09.5f°",
          northing,
          latitude.degreesDecimal,
          easting,
          longitude.degreesDecimal
        )
      case .degreesDecimalMinutes:
        return String(
          format: "%@ %02d° %06.3f′\n%@ %03d° %06.3f′",
          northing,
          latitude.degrees,
          latitude.minutesDecimal,
          easting,
          longitude.degrees,
          longitude.minutesDecimal
        )
      case .degreesMinutesSeconds:
        return String(
          format: "%@ %02d° %02d′ %02d″\n%@ %03d° %02d′ %02d″",
          northing,
          latitude.degrees,
          latitude.minutes,
          latitude.seconds,
          easting,
          longitude.degrees,
          longitude.minutes,
          longitude.seconds
        )
      case .utm:
        return coordinate.formatted(utmFormatter)
      case .mgrs:
        return MGRSHelper.fromCoordinate(coordinate, precision: .oneM) ?? ""
    }
  }

  var attributedStrings: [AttributedString] {
    var result: [AttributedString] = []
    var offset = 0

    for line in stringValue.components(separatedBy: .newlines) {
      var lineAttr = AttributedString()
      for (i, char) in line.enumerated() {
        let globalIndex = offset + i
        var attrChar = AttributedString(String(char))
        if globalIndex == currentIndex {
          attrChar.foregroundColor = UIColor.systemBackground
          attrChar.backgroundColor = .accent
        }
        lineAttr.append(attrChar)
      }
      result.append(lineAttr)
      offset += line.count + 1  // +1 for the newline that was removed by `components`
    }

    return result
  }

  private var currentIndexIsValid: Bool { isValidIndex(currentIndex) }

  init(coordinate: Coordinate) {
    self.coordinate = coordinate

    formatChangeObserver = Task { [weak self] in
      for await _ in Defaults.updates(.coordinateFormat) {
        await MainActor.run { self?.currentIndex = 0 }
      }
    }
  }

  func isValidCharacter(_ character: Character) -> Bool {
    var newCoordinateStr = stringValue
    let range = indexInString..<stringValue.index(after: indexInString)
    newCoordinateStr.replaceSubrange(range, with: String(character))
    return coordinate(from: newCoordinateStr) != nil
  }

  func add(_ digit: Character, advanceCursor: Bool = true) {
    guard
      format == .decimalDegrees || format == .degreesDecimalMinutes
        || format == .degreesMinutesSeconds
    else {
      if format == .mgrs || format == .utm {
        return  // MGRS and UTM handled differently
      }
      preconditionFailure("Invalid coordinate format")
    }

    var newCoordinateStr = stringValue
    let range = indexInString..<stringValue.index(after: indexInString)
    newCoordinateStr.replaceSubrange(range, with: String(digit))
    if let newCoordinate = coordinate(from: newCoordinateStr) {
      coordinate = newCoordinate
      if advanceCursor { advance() }
    }
  }

  func delete() {
    guard
      format == .decimalDegrees || format == .degreesDecimalMinutes
        || format == .degreesMinutesSeconds
    else {
      if format == .mgrs || format == .utm {
        return  // MGRS and UTM handled differently
      }
      preconditionFailure("Invalid coordinate format")
    }

    switch digitType {
      case .numeric: add("0", advanceCursor: false)
      case .hemisphere:
        guard
          let resetChar = [Character("N"), Character("E")].first(where: { isValidCharacter($0) })
        else {
          preconditionFailure("No valid hemisphere character at index")
        }
        add(resetChar, advanceCursor: false)
      case .open: preconditionFailure("Invalid index position")
    }
  }

  func advance() {
    let value = stringValue
    repeat {
      currentIndex += 1
      if currentIndex == value.count { currentIndex = 0 }
    } while !currentIndexIsValid
  }

  func backspace() {
    delete()
    let value = stringValue
    repeat {
      currentIndex -= 1
      if currentIndex < 0 { currentIndex = value.count - 1 }
    } while !currentIndexIsValid
  }

  func setIndex(lineIndex: Int, charIndex: Int) {
    let lines = stringValue.split(separator: "\n")
    let newIndex = lines[0..<lineIndex].map(\.count).reduce(0, +) + charIndex
    if isValidIndex(newIndex) {
      currentIndex = newIndex
    }
  }

  private func coordinate(from string: String) -> Coordinate? {
    switch format {
      case .decimalDegrees:  // N 00.00000°⏎E 000.00000°
        let northingIndex = 0
        let eastingIndex = 12
        let latitudeIndex = 2...9
        let longitudeIndex = 14...22
        let northingStr = string.slice(northingIndex)
        let eastingStr = string.slice(eastingIndex)
        let latitudeStr = string.slice(latitudeIndex)
        let longitudeStr = string.slice(longitudeIndex)
        guard northingStr == "N" || northingStr == "S",
          eastingStr == "E" || eastingStr == "W"
        else {
          return nil
        }
        let northingBinade = northingStr == "N" ? 1.0 : -1.0
        let eastingBinade = eastingStr == "E" ? 1.0 : -1.0
        guard let latitude = Double(latitudeStr),
          let longitude = Double(longitudeStr),
          (0...90).contains(latitude),
          (0..<180.0).contains(longitude)
        else {
          return nil
        }
        return .init(
          latitude: latitude * northingBinade,
          longitude: longitude * eastingBinade
        )

      case .degreesDecimalMinutes:  // N 00° 00.000′⏎E 000° 00.000′
        let northingIndex = 0
        let eastingIndex = 14
        let latitudeDegreesIndex = 2...3
        let latitudeMinutesIndex = 6...11
        let longitudeDegreesIndex = 16...18
        let longitudeMinutesIndex = 21...26
        let northingStr = string.slice(northingIndex)
        let eastingStr = string.slice(eastingIndex)
        let latitudeDegreesStr = string.slice(latitudeDegreesIndex)
        let latitudeMinutesStr = string.slice(latitudeMinutesIndex)
        let longitudeDegreesStr = string.slice(longitudeDegreesIndex)
        let longitudeMinutesStr = string.slice(longitudeMinutesIndex)
        guard northingStr == "N" || northingStr == "S",
          eastingStr == "E" || eastingStr == "W"
        else {
          return nil
        }
        let northingBinade = northingStr == "N" ? 1.0 : -1.0
        let eastingBinade = eastingStr == "E" ? 1.0 : -1.0
        guard let latitudeDegrees = Double(latitudeDegreesStr),
          let latitudeMinutes = Double(latitudeMinutesStr),
          let longitudeDegrees = Double(longitudeDegreesStr),
          let longitudeMinutes = Double(longitudeMinutesStr),
          (0...90).contains(latitudeDegrees),
          (0..<60.0).contains(latitudeMinutes),
          (0..<180).contains(longitudeDegrees),
          (0..<60.0).contains(longitudeMinutes)
        else {
          return nil
        }
        return .init(
          latitude: (latitudeDegrees + latitudeMinutes / 60) * northingBinade,
          longitude: (longitudeDegrees + longitudeMinutes / 60) * eastingBinade
        )

      case .degreesMinutesSeconds:  // N 00° 00′ 00″⏎E 000° 00′ 00″
        let northingIndex = 0
        let eastingIndex = 14
        let latitudeDegreesIndex = 2...3
        let latitudeMinutesIndex = 6...7
        let latitudeSecondsIndex = 10...11
        let longitudeDegreesIndex = 16...18
        let longitudeMinutesIndex = 21...22
        let longitudeSecondsIndex = 25...26
        let northingStr = string.slice(northingIndex)
        let eastingStr = string.slice(eastingIndex)
        let latitudeDegreesStr = string.slice(latitudeDegreesIndex)
        let latitudeMinutesStr = string.slice(latitudeMinutesIndex)
        let latitudeSecondsStr = string.slice(latitudeSecondsIndex)
        let longitudeDegreesStr = string.slice(longitudeDegreesIndex)
        let longitudeMinutesStr = string.slice(longitudeMinutesIndex)
        let longitudeSecondsStr = string.slice(longitudeSecondsIndex)
        guard northingStr == "N" || northingStr == "S",
          eastingStr == "E" || eastingStr == "W"
        else {
          return nil
        }
        let northingBinade = northingStr == "N" ? 1.0 : -1.0
        let eastingBinade = eastingStr == "E" ? 1.0 : -1.0
        guard let latitudeDegrees = Double(latitudeDegreesStr),
          let latitudeMinutes = Double(latitudeMinutesStr),
          let latitudeSeconds = Double(latitudeSecondsStr),
          let longitudeDegrees = Double(longitudeDegreesStr),
          let longitudeMinutes = Double(longitudeMinutesStr),
          let longitudeSeconds = Double(longitudeSecondsStr),
          (0...90).contains(latitudeDegrees),
          (0..<60).contains(latitudeMinutes),
          (0..<60.0).contains(latitudeSeconds),
          (0..<180).contains(longitudeDegrees),
          (0..<60).contains(longitudeMinutes),
          (0..<60.0).contains(longitudeSeconds)
        else {
          return nil
        }
        return .init(
          latitude: (latitudeDegrees + latitudeMinutes / 60 + latitudeSeconds / 3600)
            * northingBinade,
          longitude: (longitudeDegrees + longitudeMinutes / 60 + longitudeSeconds / 3600)
            * eastingBinade
        )

      case .utm:
        return try? Coordinate(string, format: .utm)

      case .mgrs:
        return MGRSHelper.toCoordinate(string)
    }
  }

  private func isValidIndex(_ index: Int) -> Bool {
    guard
      format == .decimalDegrees || format == .degreesDecimalMinutes
        || format == .degreesMinutesSeconds
    else {
      return true
    }
    guard index >= 0 && index < stringValue.count else {
      return false
    }

    return digitType(for: index) != .open
  }

  private func digitType(for index: Int) -> DigitType {
    switch format {
      case .decimalDegrees, .degreesDecimalMinutes, .degreesMinutesSeconds:
        switch stringValue[indexInString(index)] {
          case "0"..."9": .numeric
          case "N", "S", "E", "W": .hemisphere
          default: .open
        }
      case .utm, .mgrs: .open
    }
  }

  private func indexInString(_ index: Int) -> String.Index {
    stringValue.index(stringValue.startIndex, offsetBy: index)
  }

  enum DigitType {
    case numeric
    case hemisphere
    case open
  }
}
