import Defaults
import DefaultsMacros
import Foundation
import SwiftUI

@MainActor
@Observable
final class TOTEntryManager {
  private static let defaultLeadTimeSec = 30.0 * 60.0
  private static let expectedDigitCount = 6

  private static let zuluModeIndicator = String(
    localized: "Z",
    comment: "Zulu (UTC) time designator"
  )
  private static let localFallbackIndicator = String(
    localized: "L",
    comment: "Fallback local-time designator when a timezone abbreviation is unavailable"
  )
  private static let localTimezoneFallbackName = String(
    localized: "Local",
    comment: "Fallback name for the target’s local timezone when no abbreviation is available"
  )

  private static let relativeDateFormatter: RelativeDateTimeFormatter = {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.dateTimeStyle = .numeric
    return formatter
  }()

  private static let compactTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HHmmss"
    return formatter
  }()

  private static let colonSeparatedTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()

  var timeOnTarget: Date
  let targetCoordinate: Coordinate

  @ObservableDefault(.TOTDisplayMode)
  @ObservationIgnored var displayMode: DisplayMode

  private(set) var currentIndex = 0

  private let dateProvider: DateProvider
  private var formatChangeObserver: Task<Void, Never>?
  private var targetTimezone: TimeZone?

  var stringValue: String {
    let formatter = Self.compactTimeFormatter

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
        modeIndicator = Self.zuluModeIndicator
      case .local:
        let timezone = targetTimezone ?? TimeZone.current
        modeIndicator = timezone.abbreviation(for: timeOnTarget) ?? Self.localFallbackIndicator
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
    let formatter = Self.colonSeparatedTimeFormatter

    switch displayMode {
      case .local:
        formatter.timeZone = TimeZone(identifier: "UTC")
        return "\(formatter.string(from: timeOnTarget)) \(Self.zuluModeIndicator)"
      case .zulu:
        let timezone = targetTimezone ?? TimeZone.current
        formatter.timeZone = timezone
        let abbreviation =
          timezone.abbreviation(for: timeOnTarget) ?? Self.localTimezoneFallbackName
        return "\(formatter.string(from: timeOnTarget)) \(abbreviation)"
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

  private var currentIndexIsValid: Bool { isValidIndex(currentIndex) }

  private var indexInString: String.Index {
    stringValue.index(stringValue.startIndex, offsetBy: currentIndex)
  }

  init(timeOnTarget: Date?, targetCoordinate: Coordinate, dateProvider: DateProvider = .system) {
    self.targetCoordinate = targetCoordinate
    self.dateProvider = dateProvider

    if let timeOnTarget {
      self.timeOnTarget = timeOnTarget
    } else {
      self.timeOnTarget = dateProvider.now().addingTimeInterval(Self.defaultLeadTimeSec)
    }

    formatChangeObserver = Task { [weak self] in
      for await _ in Defaults.updates(.TOTDisplayMode) {
        self?.currentIndex = 0
      }
    }

    Task { await self.fetchTargetTimezone() }
  }

  func isValidCharacter(_ character: Character) -> Bool {
    guard character.isNumber else { return false }

    let position = timePosition(for: currentIndex)
    guard let position else { return false }

    let digit = Int(String(character))!

    switch position {
      case .hourTens:
        return digit <= 2
      case .hourOnes:
        let hourTens = digitValue(at: index(of: .hourTens))
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

  func setIndex(charIndex: Int) {
    if isValidIndex(charIndex) {
      currentIndex = charIndex
    }
  }

  /// Maps a horizontal tap location within the monospaced time display to the corresponding
  /// character index and selects it. `lineWidth` is the rendered width of the display, supplied by
  /// the view's `GeometryReader` so hit-testing matches what the user actually sees.
  func selectIndex(atTapX tapX: CGFloat, lineWidth: CGFloat) {
    let characterCount = stringValue.count
    guard characterCount > 0, lineWidth > 0 else { return }

    let widthPerCharacter = lineWidth / CGFloat(characterCount)
    let charIndex = Int(tapX / widthPerCharacter)
    guard charIndex < characterCount else { return }

    setIndex(charIndex: charIndex)
  }

  private func time(from string: String) -> Date? {
    // Remove colons and any timezone abbreviation (everything after the space)
    var cleanString = string.replacingOccurrences(of: ":", with: "")
    if let spaceIndex = cleanString.firstIndex(of: " ") {
      cleanString = String(cleanString[..<spaceIndex])
    }

    guard cleanString.count == Self.expectedDigitCount else { return nil }

    let formatter = Self.compactTimeFormatter

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

  /// The editable digit at a given character index within the `HH:MM:SS TZ` display, or `nil` for
  /// the colons, the space, and the timezone characters.
  private func timePosition(for index: Int) -> TimePosition? {
    TimePosition.allCases.first { $0.characterIndex == index }
  }

  private func index(of position: TimePosition) -> Int {
    position.characterIndex
  }

  private func digitValue(at index: Int) -> Int {
    let stringIndex = stringValue.index(stringValue.startIndex, offsetBy: index)
    let char = stringValue[stringIndex]
    return Int(String(char)) ?? 0
  }

  private func fetchTargetTimezone() async {
    targetTimezone = await TimeZoneHelper.shared.timeZone(for: targetCoordinate)
  }

  /// An editable digit within the `HH:MM:SS TZ` display, paired with its character index.
  /// Indices skip the colons (2, 5), the space (8), and the trailing timezone (9+).
  enum TimePosition: CaseIterable {
    case hourTens, hourOnes, minuteTens, minuteOnes, secondTens, secondOnes

    var characterIndex: Int {
      switch self {
        case .hourTens: return 0
        case .hourOnes: return 1
        case .minuteTens: return 3
        case .minuteOnes: return 4
        case .secondTens: return 6
        case .secondOnes: return 7
      }
    }
  }
}
