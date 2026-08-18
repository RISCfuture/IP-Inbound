import Defaults
import Foundation

func localizedName(of unit: Unit, style: Formatter.UnitStyle = .long) -> String {
  let formatter = MeasurementFormatter()
  formatter.unitStyle = style
  formatter.unitOptions = .providedUnit
  return formatter.string(from: unit)
}

func format(coordinate: Coordinate) -> String? {
  let style = CoordinateFormatStyle(format: Defaults[.coordinateFormat])
  return coordinate.formatted(style)
}

let localTOTFormatStyle = Date.FormatStyle(
  date: .omitted,
  time: .shortened,
  timeZone: .autoupdatingCurrent,
  capitalizationContext: .standalone
)
/// Zulu time is an aviation convention with a fixed presentation — four 24-hour digits followed by a
/// `Z` — so it renders verbatim against a Gregorian calendar rather than through the reader's
/// calendar and time-of-day conventions.
let zuluTOTFormatStyle = Date.VerbatimFormatStyle(
  format:
    "\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)Z",
  timeZone: .gmt,
  calendar: .init(identifier: .gregorian)
)
