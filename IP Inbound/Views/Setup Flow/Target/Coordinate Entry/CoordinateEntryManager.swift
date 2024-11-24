import Defaults
import DefaultsMacros
import Foundation
import LocationFormatter
import SwiftUI

private extension Double {
    var degreesDecimal: Double { magnitude }
    var degrees: Int { Int(degreesDecimal) }
    var minutesDecimal: Double { degreesDecimal.subunitPortion(divisor: 60) }
    var minutes: Int { Int(minutesDecimal) }
    var secondsDecimal: Double { degreesDecimal.subunitPortion(divisor: 3600, modulus: 60) }
    var seconds: Int { Int(secondsDecimal) }

    func subunitPortion(divisor: Int, modulus: Int? = nil) -> Double {
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
    @MainActor private let UTMFormatter = LocationCoordinateFormatter(format: .utm)
    private var formatChangeObserver: Task<Void, Never>?

    var digitCount: Int { stringValue.count }

    var digitType: DigitType { digitType(for: currentIndex) }

    var indexInLinesArray: (Int, Int) {
        var lineIndex = 0, charIndex = 0
        for (globalIndex, char) in stringValue.enumerated() {
            if globalIndex == currentIndex {
                return (lineIndex, charIndex)
            }
            if char == "\n" {
                lineIndex += 1
                charIndex = -1 // the start of the next line is the character AFTER the newline
            } else {
                charIndex += 1
            }
        }
        fatalError("currentIndex out of bounds")
    }

    private var latitude: Double { coordinate.latitudeDeg }
    private var longitude: Double { coordinate.longitudeDeg }
    private var northing: String { coordinate.latitudeDeg.sign == .minus ? "S" : "N" }
    private var easting: String { coordinate.longitudeDeg.sign == .minus ? "W" : "E" }

    var stringValue: String {
        switch format {
            case .decimalDegrees:
                String(format: "%@ %08.5f°\n%@ %09.5f°",
                       northing, latitude.degreesDecimal,
                       easting, longitude.degreesDecimal)
            case .degreesDecimalMinutes:
                String(format: "%@ %02d° %06.3f′\n%@ %03d° %06.3f′",
                       northing, latitude.degrees, latitude.minutesDecimal,
                       easting, longitude.degrees, longitude.minutesDecimal)
            case .degreesMinutesSeconds:
                String(format: "%@ %02d° %02d′ %05.2f″\n%@ %03d° %02d′ %05.2f″",
                       northing, latitude.degrees, latitude.minutes, latitude.secondsDecimal,
                       easting, longitude.degrees, longitude.minutes, longitude.secondsDecimal)
            case .utm: // handled by UTMFormatter
                UTMFormatter.string(for: coordinate.toCoreLocation)!
            case .geoURI:
                preconditionFailure("Invalid coordinate format")
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
            offset += line.count + 1 // +1 for the newline that was removed by `components`
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

    func digit(at index: Int) -> Character { Array(stringValue)[index] }

    func isValidCharacter(_ character: Character) -> Bool {
        var newCoordinateStr = stringValue
        newCoordinateStr.replaceSubrange(indexInString...indexInString, with: String(character))
        return coordinate(from: newCoordinateStr) != nil
    }

    func add(_ digit: Character, advanceCursor: Bool = true) {
        guard format == .decimalDegrees || format == .degreesDecimalMinutes || format == .degreesMinutesSeconds else {
            preconditionFailure("Invalid coordinate format")
        }

        var newCoordinateStr = stringValue
        newCoordinateStr.replaceSubrange(indexInString...indexInString, with: String(digit))
        if let newCoordinate = coordinate(from: newCoordinateStr) {
            coordinate = newCoordinate
            if advanceCursor { advance() }
        }
    }

    func delete() {
        guard format == .decimalDegrees || format == .degreesDecimalMinutes || format == .degreesMinutesSeconds else {
            preconditionFailure("Invalid coordinate format")
        }

        switch digitType {
            case .numeric: add("0", advanceCursor: false)
            case .hemisphere:
                let resetChar = [Character("N"), Character("E")].first(where: { isValidCharacter($0) })!
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
            case .decimalDegrees: // N 00.00000°⏎E 000.00000°
                let northingIndex = 0,
                    eastingIndex = 12,
                    latitudeIndex = 2...9,
                    longitudeIndex = 14...22
                let northingStr = string.slice(northingIndex),
                    eastingStr = string.slice(eastingIndex),
                    latitudeStr = string.slice(latitudeIndex),
                    longitudeStr = string.slice(longitudeIndex)
                guard northingStr == "N" || northingStr == "S",
                      eastingStr == "E" || eastingStr == "W" else {
                    return nil
                }
                let northingBinade = northingStr == "N" ? 1.0 : -1.0,
                    eastingBinade = eastingStr == "E" ? 1.0 : -1.0
                guard let latitude = Double(latitudeStr),
                      let longitude = Double(longitudeStr),
                      (0...90).contains(latitude),
                      (0..<180.0).contains(longitude) else {
                    return nil
                }
                return .init(latitude: latitude * northingBinade,
                             longitude: longitude * eastingBinade)

            case .degreesDecimalMinutes: // N 00° 00.000′⏎E 000° 00.000′
                let northingIndex = 0,
                    eastingIndex = 14,
                    latitudeDegreesIndex = 2...3,
                    latitudeMinutesIndex = 6...11,
                    longitudeDegreesIndex = 16...18,
                    longitudeMinutesIndex = 21...26
                let northingStr = string.slice(northingIndex),
                    eastingStr = string.slice(eastingIndex),
                    latitudeDegreesStr = string.slice(latitudeDegreesIndex),
                    latitudeMinutesStr = string.slice(latitudeMinutesIndex),
                    longitudeDegreesStr = string.slice(longitudeDegreesIndex),
                    longitudeMinutesStr = string.slice(longitudeMinutesIndex)
                guard northingStr == "N" || northingStr == "S",
                      eastingStr == "E" || eastingStr == "W" else {
                    return nil
                }
                let northingBinade = northingStr == "N" ? 1.0 : -1.0,
                    eastingBinade = eastingStr == "E" ? 1.0 : -1.0
                guard let latitudeDegrees = Double(latitudeDegreesStr),
                      let latitudeMinutes = Double(latitudeMinutesStr),
                      let longitudeDegrees = Double(longitudeDegreesStr),
                      let longitudeMinutes = Double(longitudeMinutesStr),
                      (0...90).contains(latitudeDegrees),
                      (0..<60.0).contains(latitudeMinutes),
                      (0..<180).contains(longitudeDegrees),
                      (0..<60.0).contains(longitudeMinutes) else {
                    return nil
                }
                return .init(latitude: (latitudeDegrees + latitudeMinutes / 60) * northingBinade,
                             longitude: (longitudeDegrees + longitudeMinutes / 60) * eastingBinade)

            case .degreesMinutesSeconds: // N 00° 00′ 00.00″⏎E 000° 00′ 00.00″
                let northingIndex = 0,
                    eastingIndex = 17,
                    latitudeDegreesIndex = 2...3,
                    latitudeMinutesIndex = 6...7,
                    latitudeSecondsIndex = 10...14,
                    longitudeDegreesIndex = 19...21,
                    longitudeMinutesIndex = 24...25,
                    longitudeSecondsIndex = 28...32
                let northingStr = string.slice(northingIndex),
                    eastingStr = string.slice(eastingIndex),
                    latitudeDegreesStr = string.slice(latitudeDegreesIndex),
                    latitudeMinutesStr = string.slice(latitudeMinutesIndex),
                    latitudeSecondsStr = string.slice(latitudeSecondsIndex),
                    longitudeDegreesStr = string.slice(longitudeDegreesIndex),
                    longitudeMinutesStr = string.slice(longitudeMinutesIndex),
                    longitudeSecondsStr = string.slice(longitudeSecondsIndex)
                guard northingStr == "N" || northingStr == "S",
                      eastingStr == "E" || eastingStr == "W" else {
                    return nil
                }
                let northingBinade = northingStr == "N" ? 1.0 : -1.0,
                    eastingBinade = eastingStr == "E" ? 1.0 : -1.0
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
                      (0..<60.0).contains(longitudeSeconds) else {
                    return nil
                }
                return .init(latitude: (latitudeDegrees + latitudeMinutes / 60 + latitudeSeconds / 3600) * northingBinade,
                             longitude: (longitudeDegrees + longitudeMinutes / 60 + longitudeSeconds / 3600) * eastingBinade)

            case .utm:
                guard let location = try? UTMFormatter.coordinate(from: string) else {
                    return nil
                }
                return .init(location)

            case .geoURI:
                preconditionFailure("Invalid format")
        }
    }

    private func isValidIndex(_ index: Int) -> Bool {
        guard format == .decimalDegrees || format == .degreesDecimalMinutes || format == .degreesMinutesSeconds else {
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
            case .utm: .open
            case .geoURI: preconditionFailure("Invalid coordinate format")
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
