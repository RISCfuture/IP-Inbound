import Foundation

let distanceNumberFormatStyle = FloatingPointFormatStyle<Double>.number.rounded(increment: 0.1)
let distanceFormatStyle = Measurement<UnitLength>.FormatStyle(
  width: .abbreviated,
  usage: .asProvided,
  numberFormatStyle: distanceNumberFormatStyle
)

let speedNumberFormatStyle = FloatingPointFormatStyle<Double>.number.rounded(increment: 1.0)
let speedFormatStyle = Measurement<UnitSpeed>.FormatStyle(
  width: .abbreviated,
  usage: .asProvided,
  numberFormatStyle: speedNumberFormatStyle
)

extension Bearing {
  struct FormatStyle: Foundation.FormatStyle {
    private static let headingNumberFormatStyle = FloatingPointFormatStyle<Double>.number.rounded(
      increment: 1.0
    )
    private static let headingFormatStyle = Measurement<UnitAngle>.FormatStyle(
      width: .narrow,
      usage: .asProvided,
      numberFormatStyle: headingNumberFormatStyle
    )

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
}
