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

/// The datum letter a bearing is suffixed with.
///
/// The letter is inside the localized string rather than appended to it, so a translation can place
/// it wherever that language puts it.
private func datumSuffixed(
  _ angle: Measurement<UnitAngle>,
  style: Measurement<UnitAngle>.FormatStyle?,
  isMagnetic: Bool
) -> String {
  let degrees = (style ?? headingFormatStyle).format(angle)
  return isMagnetic
    ? String(localized: "\(degrees)M", bundle: .guidance)
    : String(localized: "\(degrees)T", bundle: .guidance)
}

/// A magnetic bearing as a whole number of degrees followed by its datum letter — `"225°M"`.
///
/// Concrete rather than a `Bearing<Datum>.FormatStyle` generic over the datum: a generic type vended
/// from this framework and specialized in an app cannot have its metadata instantiated by the
/// Previews JIT, which segfaults every preview that formats a bearing — the CDI among them.
public struct MagneticBearingFormatStyle: FormatStyle, Sendable {
  private let measurementStyle: Measurement<UnitAngle>.FormatStyle?

  public init(measurementStyle: Measurement<UnitAngle>.FormatStyle? = nil) {
    self.measurementStyle = measurementStyle
  }

  public func format(_ value: MagneticBearing) -> String {
    datumSuffixed(value.angle, style: measurementStyle, isMagnetic: true)
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
          datumSuffixed(bearing.angle, style: measurementStyle, isMagnetic: false)
        case .magnetic(let bearing):
          datumSuffixed(bearing.angle, style: measurementStyle, isMagnetic: true)
      }
    }
  }
}

extension FormatStyle where Self == MagneticBearingFormatStyle {
  /// A magnetic bearing as degrees and datum letter — `"225°M"`.
  public static var bearing: Self { .init() }
}

extension FormatStyle where Self == OffsetBearing.FormatStyle {
  /// An offset bearing in whichever datum the pilot entered it in.
  public static var bearing: Self { .init() }
}
