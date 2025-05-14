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

func / <U: Dimension>(lhs: Measurement<U>, rhs: Measurement<U>) -> Double {
    lhs.converted(to: .baseUnit()).value / rhs.converted(to: .baseUnit()).value
}

func * (lhs: Measurement<UnitSpeed>, rhs: Measurement<UnitDuration>) -> Measurement<UnitLength> {
    let value = lhs.converted(to: .metersPerSecond).value * rhs.converted(to: .seconds).value
    return .init(value: value, unit: .meters)
}

func tan(_ measurement: Measurement<UnitAngle>) -> Double {
    tan(measurement.converted(to: .radians).value)
}

// swiftlint:enable static_operator

extension Measurement where UnitType == UnitDuration {
    var afterNow: Date { after(date: Date()) }
    var beforeNow: Date { before(date: Date()) }

    func after(date: Date) -> Date {
        date.addingTimeInterval(converted(to: .seconds).value)
    }

    func before(date: Date) -> Date {
        date.addingTimeInterval(-converted(to: .seconds).value)
    }
}
