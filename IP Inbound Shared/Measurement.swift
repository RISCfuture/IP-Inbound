import Foundation

// swiftlint:disable static_operator

func / (lhs: Measurement<UnitLength>, rhs: Measurement<UnitDuration>) -> Measurement<UnitSpeed> {
  let value = lhs.converted(to: .meters).value / rhs.converted(to: .seconds).value
  return .init(value: value, unit: .metersPerSecond)
}

func / (lhs: Measurement<UnitLength>, rhs: Measurement<UnitSpeed>) -> Measurement<UnitDuration> {
  let value = lhs.converted(to: .meters).value / rhs.converted(to: .metersPerSecond).value
  return .init(value: value, unit: .seconds)
}

/// The time taken to change speed by `lhs` at the acceleration `rhs`.
func / (
  lhs: Measurement<UnitSpeed>,
  rhs: Measurement<UnitAcceleration>
) -> Measurement<UnitDuration> {
  let value =
    lhs.converted(to: .metersPerSecond).value
    / rhs.converted(to: .metersPerSecondSquared).value
  return .init(value: value, unit: .seconds)
}

func / <U: Dimension>(lhs: Measurement<U>, rhs: Measurement<U>) -> Double {
  lhs.converted(to: .baseUnit()).value / rhs.converted(to: .baseUnit()).value
}

func * (lhs: Measurement<UnitSpeed>, rhs: Measurement<UnitDuration>) -> Measurement<UnitLength> {
  let value = lhs.converted(to: .metersPerSecond).value * rhs.converted(to: .seconds).value
  return .init(value: value, unit: .meters)
}

func * (lhs: Measurement<UnitDuration>, rhs: Measurement<UnitSpeed>) -> Measurement<UnitLength> {
  rhs * lhs
}

/// The speed gained by accelerating at `lhs` for `rhs`.
func * (
  lhs: Measurement<UnitAcceleration>,
  rhs: Measurement<UnitDuration>
) -> Measurement<UnitSpeed> {
  let value =
    lhs.converted(to: .metersPerSecondSquared).value * rhs.converted(to: .seconds).value
  return .init(value: value, unit: .metersPerSecond)
}

/// The elapsed time from `rhs` to `lhs`, negative when `lhs` precedes `rhs`.
func - (lhs: Date, rhs: Date) -> Measurement<UnitDuration> {
  .init(value: lhs.timeIntervalSince(rhs), unit: .seconds)
}

prefix func - <U: Dimension>(measurement: Measurement<U>) -> Measurement<U> {
  .init(value: -measurement.value, unit: measurement.unit)
}

// swiftlint:enable static_operator

extension Measurement where UnitType: Dimension {
  /// Zero, expressed in the dimension's base unit. Comparisons convert, so this is a valid zero to
  /// test any measurement of the dimension against.
  static var zero: Self { .init(value: 0, unit: .baseUnit()) }

  /// The absolute value, in the same unit.
  var magnitude: Self { .init(value: value.magnitude, unit: unit) }
}

extension Measurement where UnitType == UnitAcceleration {
  /// Standard gravity.
  static var gravity: Self { .init(value: 1, unit: .gravity) }
}

extension Measurement where UnitType == UnitAngle {
  /// The angle in radians, as the dimensionless number the trigonometric functions take.
  var radians: Double { converted(to: .radians).value }
}

extension Measurement where UnitType == UnitDuration {
  /// The equivalent stdlib `Duration`, for the `Duration`-based format styles.
  var duration: Duration { .seconds(converted(to: .seconds).value) }

  func after(date: Date) -> Date {
    date.addingTimeInterval(converted(to: .seconds).value)
  }

  func before(date: Date) -> Date {
    date.addingTimeInterval(-converted(to: .seconds).value)
  }
}
