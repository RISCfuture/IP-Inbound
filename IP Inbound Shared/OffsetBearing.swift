import Foundation
import MeasurementKit
import MeasurementKitLocation

/// A run-in offset bearing in whichever datum the pilot entered it in.
///
/// `Bearing` carries its datum in the type, but IP Inbound lets the pilot pick true or magnetic on
/// the setup form, so the datum is only known at runtime. This is the pair of possibilities as a
/// value; converting it in either direction hands back a statically typed bearing again.
public enum OffsetBearing: Hashable, Sendable {
  case `true`(TrueBearing)
  case magnetic(MagneticBearing)

  /// The angle clockwise from the datum's north.
  private var angle: Measurement<UnitAngle> {
    switch self {
      case .true(let bearing): bearing.angle
      case .magnetic(let bearing): bearing.angle
    }
  }

  /// The bearing in degrees, in [0, 360).
  public var degrees: Double { angle.degrees }

  /// Whether the bearing was entered against true north rather than magnetic north.
  public var isTrue: Bool {
    switch self {
      case .true: true
      case .magnetic: false
    }
  }

  /// The bearing opposite this one, in the same datum.
  public var reciprocal: Self {
    switch self {
      case .true(let bearing): .true(bearing.reciprocal)
      case .magnetic(let bearing): .magnetic(bearing.reciprocal)
    }
  }

  /// A bearing of `degrees` in the datum `isTrue` selects.
  ///
  /// - Parameters:
  ///   - degrees: the direction in degrees, clockwise from that datum's north.
  ///   - isTrue: whether the direction was measured from true north rather than magnetic north.
  public init(degrees: Double, isTrue: Bool) {
    self = isTrue ? .true(.init(degrees: degrees)) : .magnetic(.init(degrees: degrees))
  }

  /// This bearing restated in true.
  ///
  /// - Parameter variation: the angle from true north to magnetic north, positive east.
  /// - Returns: the same direction, measured from true north.
  public func toTrue(variation: Measurement<UnitAngle>) -> TrueBearing {
    switch self {
      case .true(let bearing): bearing
      case .magnetic(let bearing): bearing.toTrue(variation: variation)
    }
  }

  /// This bearing restated in magnetic.
  ///
  /// - Parameter variation: the angle from true north to magnetic north, positive east.
  /// - Returns: the same direction, measured from magnetic north.
  public func toMagnetic(variation: Measurement<UnitAngle>) -> MagneticBearing {
    switch self {
      case .true(let bearing): bearing.toMagnetic(variation: variation)
      case .magnetic(let bearing): bearing
    }
  }
}
