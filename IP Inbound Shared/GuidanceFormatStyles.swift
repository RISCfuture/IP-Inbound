import Foundation
import MeasurementKit
import MeasurementKitLocation

/// Distances read to a tenth, the resolution the run-in is flown to.
let distanceNumberFormatStyle = FloatingPointFormatStyle<Double>.number.rounded(
  increment: 0.1
)
/// A distance with its unit, as every screen renders it.
public let distanceFormatStyle = Measurement<UnitLength>.FormatStyle(
  width: .abbreviated,
  usage: .asProvided,
  numberFormatStyle: distanceNumberFormatStyle
)

/// Speeds read to the knot; finer resolution is noise the pilot cannot fly.
let speedNumberFormatStyle = FloatingPointFormatStyle<Double>.number.rounded(
  increment: 1.0
)
/// A speed with its unit, as every screen renders it.
public let speedFormatStyle = Measurement<UnitSpeed>.FormatStyle(
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
  public struct FormatStyle: Foundation.FormatStyle, Sendable {
    private let measurementStyle: Measurement<UnitAngle>.FormatStyle

    public init(measurementStyle: Measurement<UnitAngle>.FormatStyle? = nil) {
      self.measurementStyle = measurementStyle ?? headingFormatStyle
    }

    public func format(_ value: Bearing) -> String {
      // The datum letter is inside the localized string rather than appended to it, so a
      // translation can place it wherever that language puts it.
      let angle = measurementStyle.format(value.angle)
      return Datum.abbreviation == Magnetic.abbreviation
        ? String(localized: "\(angle)M", bundle: .guidance)
        : String(localized: "\(angle)T", bundle: .guidance)
    }
  }
}

extension OffsetBearing {
  /// An offset bearing rendered in whichever datum the pilot entered it in.
  public struct FormatStyle: Foundation.FormatStyle, Sendable {
    private let measurementStyle: Measurement<UnitAngle>.FormatStyle?

    public init(measurementStyle: Measurement<UnitAngle>.FormatStyle? = nil) {
      self.measurementStyle = measurementStyle
    }

    public func format(_ value: OffsetBearing) -> String {
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
  /// A magnetic bearing as degrees and datum letter — `"225°M"`.
  public static var bearing: Self { .init() }
}

extension FormatStyle where Self == OffsetBearing.FormatStyle {
  /// An offset bearing in whichever datum the pilot entered it in.
  public static var bearing: Self { .init() }
}
