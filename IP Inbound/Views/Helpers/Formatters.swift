import Defaults
import Foundation
@preconcurrency import LocationFormatter

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
    let formatter = LocationCoordinateFormatter(format: Defaults[.coordinateFormat], displayOptions: .suffix)
    formatter.symbolStyle = .traditional
    return formatter.string(from: coordinate.toCoreLocation)
}

let distanceNumberFormatStyle = FloatingPointFormatStyle<Double>.number.rounded(increment: 0.1)
let distanceFormatStyle = Measurement<UnitLength>.FormatStyle(width: .abbreviated, usage: .asProvided, numberFormatStyle: distanceNumberFormatStyle)

let speedNumberFormatStyle = FloatingPointFormatStyle<Double>.number.rounded(increment: 1.0)
let speedFormatStyle = Measurement<UnitSpeed>.FormatStyle(width: .abbreviated, usage: .asProvided, numberFormatStyle: speedNumberFormatStyle)

let localTOTFormatStyle = Date.FormatStyle(date: .omitted, time: .shortened, timeZone: .autoupdatingCurrent, capitalizationContext: .standalone)
let zuluTOTFormatStyle = ZuluTimeFormatStyle()

extension Bearing {
    struct FormatStyle: Foundation.FormatStyle {
        private static let headingNumberFormatStyle = FloatingPointFormatStyle<Double>.number.rounded(increment: 1.0)
        private static let headingFormatStyle = Measurement<UnitAngle>.FormatStyle(width: .narrow, usage: .asProvided, numberFormatStyle: headingNumberFormatStyle)

        private let measurementStyle: Measurement<UnitAngle>.FormatStyle

        init(measurementStyle: Measurement<UnitAngle>.FormatStyle? = nil) {
            self.measurementStyle = measurementStyle ?? Self.headingFormatStyle
        }

        func format(_ value: Bearing) -> String {
            switch value.reference {
                case .magnetic:
                    String(localized: "\(measurementStyle.format(value.angle))M")
                case .true:
                    String(localized: "\(measurementStyle.format(value.angle))T")
                case .relative:
                    measurementStyle.format(value.angle)
            }
        }
    }
}

extension FormatStyle where Self == Bearing.FormatStyle {
    static var bearing: Bearing.FormatStyle { .init() }

    static func bearing(measurementStyle: Measurement<UnitAngle>.FormatStyle) -> Bearing.FormatStyle {
        .init(measurementStyle: measurementStyle)
    }
}
