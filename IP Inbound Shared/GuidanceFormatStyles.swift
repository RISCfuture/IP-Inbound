import Foundation
import MeasurementKit
import MeasurementKitLocation

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

private let headingNumberFormatStyle = FloatingPointFormatStyle<Double>.number.rounded(
  increment: 1.0
)
private let headingFormatStyle = Measurement<UnitAngle>.FormatStyle(
  width: .narrow,
  usage: .asProvided,
  numberFormatStyle: headingNumberFormatStyle
)

extension Bearing {
  /// A bearing as a whole number of degrees followed by its datum letter — `"225°M"`.
  struct FormatStyle: Foundation.FormatStyle {
    private let measurementStyle: Measurement<UnitAngle>.FormatStyle

    init(measurementStyle: Measurement<UnitAngle>.FormatStyle? = nil) {
      self.measurementStyle = measurementStyle ?? headingFormatStyle
    }

    func format(_ value: Bearing) -> String {
      // The datum letter is inside the localized string rather than appended to it, so a
      // translation can place it wherever that language puts it.
      let angle = measurementStyle.format(value.angle)
      return Datum.abbreviation == Magnetic.abbreviation
        ? String(localized: "\(angle)M")
        : String(localized: "\(angle)T")
    }
  }
}

extension OffsetBearing {
  /// An offset bearing rendered in whichever datum the pilot entered it in.
  struct FormatStyle: Foundation.FormatStyle {
    private let measurementStyle: Measurement<UnitAngle>.FormatStyle?

    init(measurementStyle: Measurement<UnitAngle>.FormatStyle? = nil) {
      self.measurementStyle = measurementStyle
    }

    func format(_ value: OffsetBearing) -> String {
      switch value {
        case .true(let bearing):
          TrueBearing.FormatStyle(measurementStyle: measurementStyle).format(bearing)
        case .magnetic(let bearing):
          MagneticBearing.FormatStyle(measurementStyle: measurementStyle).format(bearing)
      }
    }
  }
}

extension FormatStyle where Self == MagneticBearing.FormatStyle {
  static var bearing: Self { .init() }
}

extension FormatStyle where Self == OffsetBearing.FormatStyle {
  static var bearing: Self { .init() }
}
