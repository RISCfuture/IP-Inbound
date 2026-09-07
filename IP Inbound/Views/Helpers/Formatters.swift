import Defaults
import Foundation
import MeasurementKitLocation

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
