import Defaults
import Foundation

struct ZuluTimeFormatStyle: FormatStyle {
  func format(_ value: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HHmm'Z'"
    formatter.timeZone = .gmt
    return formatter.string(from: value)
  }
}

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
let zuluTOTFormatStyle = ZuluTimeFormatStyle()
