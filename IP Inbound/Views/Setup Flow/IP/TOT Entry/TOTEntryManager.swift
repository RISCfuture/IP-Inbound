import Defaults
import DefaultsMacros
import Foundation
import SwiftUI

@MainActor
@Observable
final class TOTEntryManager {
  private static let defaultLeadTime = Measurement(value: 30, unit: UnitDuration.minutes)
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

  private static let gregorianCalendar = Calendar(identifier: .gregorian)

  /// The secondary readout mirrors the primary display's fixed `HH:MM:SS` aviation layout, so it
  /// renders verbatim rather than through the reader's time-of-day conventions.
  private static let secondaryTimeFormat: Date.FormatString =
    "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)"

  var timeOnTarget: Date
  let targetCoordinate: Coordinate

  @ObservableDefault(.TOTDisplayMode)
  @ObservationIgnored var displayMode: DisplayMode

  private(set) var currentIndex = 0

  private let dateProvider: DateProvider
  private var formatChangeObserver: Task<Void, Never>?
  private var targetTimezone: TimeZone?

  /// The `HH:MM:SS TZ` edit buffer. The keypad rewrites it a character at a time and ``time(from:)``
  /// reads it back, so `String(format:)` builds it from raw components: every field is zero-padded to
  /// a fixed width and the digits stay ASCII no matter how the reader's locale renders numbers.
  var stringValue: String {
    let (hour, minute, second) = Self.hourMinuteSecond(of: timeOnTarget, in: displayTimezone)
    return String(format: "%02d:%02d:%02d %@", hour, minute, second, displayModeIndicator)
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
          attrChar.foregroundColor = Color(.systemBackground)
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
    let style = Date.VerbatimFormatStyle(
      format: Self.secondaryTimeFormat,
      timeZone: secondaryTimezone,
      calendar: Self.gregorianCalendar
    )
    return "\(timeOnTarget.formatted(style)) \(secondaryModeIndicator)"
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

  private var targetOrDeviceTimezone: TimeZone { targetTimezone ?? .current }

  /// The reference frame the editable readout is expressed in.
  private var displayTimezone: TimeZone {
    switch displayMode {
      case .local: targetOrDeviceTimezone
      case .zulu: .gmt
    }
  }

  /// The other reference frame, shown beneath the editable readout.
  private var secondaryTimezone: TimeZone {
    switch displayMode {
      case .local: .gmt
      case .zulu: targetOrDeviceTimezone
    }
  }

  private var displayModeIndicator: String {
    switch displayMode {
      case .local:
        displayTimezone.abbreviation(for: timeOnTarget) ?? Self.localFallbackIndicator
      case .zulu: Self.zuluModeIndicator
    }
  }

  private var secondaryModeIndicator: String {
    switch displayMode {
      case .local: Self.zuluModeIndicator
      case .zulu:
        secondaryTimezone.abbreviation(for: timeOnTarget) ?? Self.localTimezoneFallbackName
    }
  }

  init(timeOnTarget: Date?, targetCoordinate: Coordinate, dateProvider: DateProvider = .system) {
    self.targetCoordinate = targetCoordinate
    self.dateProvider = dateProvider

    if let timeOnTarget {
      self.timeOnTarget = timeOnTarget
    } else {
      self.timeOnTarget = Self.defaultLeadTime.after(date: dateProvider.now())
    }

    formatChangeObserver = Task { [weak self] in
      for await _ in Defaults.updates(.TOTDisplayMode) {
        self?.currentIndex = 0
      }
    }

    Task { await self.fetchTargetTimezone() }
  }

  private static func hourMinuteSecond(
    of date: Date,
    in timezone: TimeZone
  ) -> (hour: Int, minute: Int, second: Int) {
    var calendar = gregorianCalendar
    calendar.timeZone = timezone
    let components = calendar.dateComponents([.hour, .minute, .second], from: date)
    return (components.hour ?? 0, components.minute ?? 0, components.second ?? 0)
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
    // Drop the colons and the trailing timezone abbreviation (everything after the space).
    let digits = string.prefix { $0 != " " }.filter { $0 != ":" }
    guard digits.count == Self.expectedDigitCount,
      let hour = Int(digits.prefix(2)), (0...23).contains(hour),
      let minute = Int(digits.dropFirst(2).prefix(2)), (0...59).contains(minute),
      let second = Int(digits.dropFirst(4).prefix(2)), (0...59).contains(second)
    else { return nil }

    var calendar = Self.gregorianCalendar
    calendar.timeZone = displayTimezone

    let nowInstant = dateProvider.now()
    var components = calendar.dateComponents([.year, .month, .day], from: nowInstant)
    (components.hour, components.minute, components.second) = (hour, minute, second)

    guard var newDate = calendar.date(from: components) else { return nil }

    if newDate < nowInstant {
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

  isolated deinit { formatChangeObserver?.cancel() }

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
