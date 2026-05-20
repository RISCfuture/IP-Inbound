import Defaults
import DefaultsMacros
import Foundation
import SwiftUI

@MainActor
@Observable
final class TOTEntryManager {
  private static let relativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.dateTimeStyle = .numeric
    return formatter
  }()

  var timeOnTarget: Date
  let targetCoordinate: Coordinate
  private let dateProvider: DateProvider

  @ObservableDefault(.TOTDisplayMode)
  @ObservationIgnored var displayMode: DisplayMode

  private(set) var currentIndex = 0
  private var formatChangeObserver: Task<Void, Never>?

  var digitCount: Int { stringValue.count }

  var indexInLinesArray: (Int, Int) {
    var lineIndex = 0
    var charIndex = 0
    for (globalIndex, char) in stringValue.enumerated() {
      if globalIndex == currentIndex {
        return (lineIndex, charIndex)
      }
      if char == "\n" {
        lineIndex += 1
        charIndex = -1
      } else {
        charIndex += 1
      }
    }
    fatalError("currentIndex out of bounds")
  }

  var stringValue: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HHmmss"

    switch displayMode {
      case .local:
        formatter.timeZone = targetTimezone ?? TimeZone.current
      case .zulu:
        formatter.timeZone = TimeZone(identifier: "UTC")
    }

    let timeString = formatter.string(from: timeOnTarget)

    let hours = String(timeString.prefix(2))
    let minutes = String(timeString.dropFirst(2).prefix(2))
    let seconds = String(timeString.dropFirst(4).prefix(2))

    let modeIndicator: String
    switch displayMode {
      case .zulu:
        modeIndicator = "Z"
      case .local:
        // Show the actual timezone abbreviation (e.g., PST, EDT, etc.)
        let tz = targetTimezone ?? TimeZone.current
        modeIndicator = tz.abbreviation(for: timeOnTarget) ?? "L"
    }
    return "\(hours):\(minutes):\(seconds) \(modeIndicator)"
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
      offset += line.count + 1
    }

    return result
  }

  var secondaryTimeString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"

    switch displayMode {
      case .local:
        // When in local mode, show Zulu time as secondary
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: timeOnTarget) + " Z"
      case .zulu:
        // When in Zulu mode, show target local time as secondary with its timezone abbreviation
        let tz = targetTimezone ?? TimeZone.current
        formatter.timeZone = tz
        let abbreviation = tz.abbreviation(for: timeOnTarget) ?? "Local"
        return formatter.string(from: timeOnTarget) + " \(abbreviation)"
    }
  }

  var relativeTimeString: String {
    let nowInstant = dateProvider.now()
    let interval = timeOnTarget.timeIntervalSince(nowInstant)

    // Handle the edge case where time might be in the past but will be adjusted to tomorrow
    if interval < 0 {
      let tomorrowTime =
        Calendar.current.date(byAdding: .day, value: 1, to: timeOnTarget) ?? timeOnTarget
      return Self.relativeDateFormatter.localizedString(for: tomorrowTime, relativeTo: nowInstant)
    }

    return Self.relativeDateFormatter.localizedString(for: timeOnTarget, relativeTo: nowInstant)
  }

  private var targetTimezone: TimeZone?

  private var currentIndexIsValid: Bool { isValidIndex(currentIndex) }

  private var indexInString: String.Index {
    stringValue.index(stringValue.startIndex, offsetBy: currentIndex)
  }

  init(timeOnTarget: Date?, targetCoordinate: Coordinate, dateProvider: DateProvider = .system) {
    self.targetCoordinate = targetCoordinate
    self.dateProvider = dateProvider

    if let tot = timeOnTarget {
      self.timeOnTarget = tot
    } else {
      self.timeOnTarget = dateProvider.now().addingTimeInterval(30 * 60)
    }

    formatChangeObserver = Task { [weak self] in
      for await _ in Defaults.updates(.TOTDisplayMode) {
        await MainActor.run { self?.currentIndex = 0 }
      }
    }

    Task { @MainActor in
      await self.fetchTargetTimezone()
    }
  }

  func digit(at index: Int) -> Character { Array(stringValue)[index] }

  func isValidCharacter(_ character: Character) -> Bool {
    guard character.isNumber else { return false }

    let position = getTimePosition(for: currentIndex)
    guard let position else { return false }

    let digit = Int(String(character))!

    switch position {
      case .hourTens:
        return digit <= 2
      case .hourOnes:
        let hourTens = getDigit(at: getIndexForPosition(.hourTens))
        return hourTens == 2 ? digit <= 3 : true
      case .minuteTens:
        return digit <= 5
      case .minuteOnes:
        return true
      case .secondTens:
        return digit <= 5
      case .secondOnes:
        return true
    }
  }

  func add(_ digit: Character, advanceCursor: Bool = true) {
    guard isValidCharacter(digit) else { return }

    var newTimeString = stringValue
    let range = indexInString..<stringValue.index(after: indexInString)
    newTimeString.replaceSubrange(range, with: String(digit))

    if let newTime = time(from: newTimeString) {
      timeOnTarget = newTime
      if advanceCursor { advance() }
    }
  }

  func delete() {
    add("0", advanceCursor: false)
  }

  func advance() {
    repeat {
      currentIndex += 1
      if currentIndex >= stringValue.count {
        currentIndex = 0
      }
    } while !currentIndexIsValid
  }

  func backspace() {
    delete()
    repeat {
      currentIndex -= 1
      if currentIndex < 0 {
        currentIndex = stringValue.count - 1
      }
    } while !currentIndexIsValid
  }

  func setIndex(lineIndex _: Int, charIndex: Int) {
    let newIndex = charIndex
    if isValidIndex(newIndex) {
      currentIndex = newIndex
    }
  }

  func toggleDisplayMode() {
    switch displayMode {
      case .local:
        displayMode = .zulu
      case .zulu:
        displayMode = .local
    }
    Defaults[.TOTDisplayMode] = displayMode
  }

  private func time(from string: String) -> Date? {
    // Remove colons and any timezone abbreviation (everything after the space)
    var cleanString = string.replacingOccurrences(of: ":", with: "")
    if let spaceIndex = cleanString.firstIndex(of: " ") {
      cleanString = String(cleanString[..<spaceIndex])
    }

    guard cleanString.count == 6 else { return nil }

    let formatter = DateFormatter()
    formatter.dateFormat = "HHmmss"

    switch displayMode {
      case .local:
        formatter.timeZone = targetTimezone ?? TimeZone.current
      case .zulu:
        formatter.timeZone = TimeZone(identifier: "UTC")
    }

    // Use a calendar with the appropriate timezone
    var calendar = Calendar.current
    calendar.timeZone = formatter.timeZone ?? TimeZone.current

    let nowInstant = dateProvider.now()
    var components = calendar.dateComponents([.year, .month, .day], from: nowInstant)

    guard let timeFromString = formatter.date(from: cleanString) else { return nil }
    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: timeFromString)

    components.hour = timeComponents.hour
    components.minute = timeComponents.minute
    components.second = timeComponents.second

    guard var newDate = calendar.date(from: components) else { return nil }

    // Check if the time is in the past
    if newDate.timeIntervalSince(dateProvider.now()) < 0 {
      newDate = calendar.date(byAdding: .day, value: 1, to: newDate) ?? newDate
    }

    return newDate
  }

  private func isValidIndex(_ index: Int) -> Bool {
    guard index >= 0 && index < stringValue.count else { return false }

    let stringIndex = stringValue.index(stringValue.startIndex, offsetBy: index)
    let char = stringValue[stringIndex]
    return char.isNumber
  }

  private func getTimePosition(for index: Int) -> TimePosition? {
    // Account for the space before timezone abbreviation
    // Format is HH:MM:SS TZ, so positions are:
    // 0,1 = hours, 2 = colon, 3,4 = minutes, 5 = colon, 6,7 = seconds, 8 = space, 9+ = timezone
    switch index {
      case 0: return .hourTens
      case 1: return .hourOnes
      case 3: return .minuteTens
      case 4: return .minuteOnes
      case 6: return .secondTens
      case 7: return .secondOnes
      default: return nil
    }
  }

  private func getIndexForPosition(_ position: TimePosition) -> Int {
    switch position {
      case .hourTens: return 0
      case .hourOnes: return 1
      case .minuteTens: return 3
      case .minuteOnes: return 4
      case .secondTens: return 6
      case .secondOnes: return 7
    }
  }

  private func getDigit(at index: Int) -> Int {
    let stringIndex = stringValue.index(stringValue.startIndex, offsetBy: index)
    let char = stringValue[stringIndex]
    return Int(String(char)) ?? 0
  }

  private func indexInString(_ index: Int) -> String.Index {
    stringValue.index(stringValue.startIndex, offsetBy: index)
  }

  private func fetchTargetTimezone() async {
    await TimeZoneHelper.shared.fetchTimeZone(for: targetCoordinate) { [weak self] timezone in
      self?.targetTimezone = timezone
    }
  }

  enum TimePosition {
    case hourTens, hourOnes, minuteTens, minuteOnes, secondTens, secondOnes
  }
}
