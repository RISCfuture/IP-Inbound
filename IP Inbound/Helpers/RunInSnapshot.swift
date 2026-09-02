import Defaults
import Foundation
import MeasurementKit

/// The run-in figures a Live Activity shows, rounded to the precision it displays them at.
///
/// Rounding is what makes this type worth having: fixes arrive at roughly 1 Hz, and pushing every one
/// of them at a Lock Screen readout that shows whole seconds and tenths of a mile would be a great
/// many updates the pilot could not see. Because the rounded value is `Equatable`, an `onChange` on it
/// fires only when the displayed figure actually moves.
struct RunInSnapshot: Equatable {
  /// The displayed precision of each figure, and so the threshold at which an update is worth pushing.
  private static let deltaTimeStep = Measurement(value: 5, unit: UnitDuration.seconds)
  private static let distanceFractionDigits = 1

  let ipDeltaTime: Measurement<UnitDuration>
  let distanceToIP: Measurement<UnitLength>

  /// The figures for a fix short of the IP, or `nil` once the IP is behind the aircraft — past it
  /// there is no run-in still to begin, and the Live Activity falls back to the bare countdown.
  init?(math: IPTargetMath<Target>) {
    guard !math.isPastIP,
      let ipDeltaTime = math.IPDeltaTime,
      let distanceToIP = math.pposToIP?.distance
    else { return nil }

    // The widget extension links neither `Defaults` nor the shared formatting, so the distance is
    // converted to the pilot's chosen unit here and travels ready to display. Rounding in that unit
    // is also what makes the quantisation match what they actually see.
    let displayUnit = Defaults[.distanceUnit].distanceUnit
    let step = Measurement(
      value: pow(10, -Double(Self.distanceFractionDigits)),
      unit: displayUnit
    )

    self.ipDeltaTime = ipDeltaTime.rounded(to: Self.deltaTimeStep)
    self.distanceToIP = distanceToIP.converted(to: displayUnit).rounded(to: step)
  }
}

extension Measurement where UnitType: Dimension {
  /// This measurement rounded to the nearest whole multiple of `step`.
  fileprivate func rounded(to step: Self) -> Self {
    let stepValue = step.converted(to: unit).value
    guard stepValue > 0 else { return self }
    return .init(value: (value / stepValue).rounded() * stepValue, unit: unit)
  }
}
