import MeasurementKit
import SwiftUI

/// How early or late an arrival is tracking against its time-on-target, paired with the readout color
/// and direction icon. Shared by the Fly timing display, the post-pass verdict, and the watch CDI so a
/// given tier always reads identically across the phone and watch.
public enum TimingTier: CaseIterable, Hashable {
  case tooSlowWarning
  case tooSlowCaution
  case onTime
  case tooFastCaution
  case tooFastWarning

  /// On-time window the run-in guidance flies to: arrivals within this much of the time-on-target
  /// read as on-time.
  public static let runInOnTimeDeltaTOT = Measurement(value: 30, unit: UnitDuration.seconds)

  /// Allowable deviation from target speed, as a fraction of target speed, before the arrival leaves
  /// the caution band for a warning — equivalently, the fraction of the nominal flight time that
  /// bounds the caution band.
  private static let speedDeviation = 0.1

  /// The bright asset color for this tier: green on-time, then the too-slow / too-fast palette in
  /// caution or warning shades.
  public var color: Color {
    switch self {
      case .tooSlowWarning: .init("TooSlowWarning")
      case .tooSlowCaution: .init("TooSlowCaution")
      case .onTime: .init("OnTime")
      case .tooFastCaution: .init("TooFastCaution")
      case .tooFastWarning: .init("TooFastWarning")
    }
  }

  /// The direction icon for this tier: chevrons up when late, down when early, doubled at the warning
  /// threshold, and a checkmark on-time.
  public var systemImage: String {
    switch self {
      case .tooSlowWarning: "chevron.up.2"
      case .tooSlowCaution: "chevron.up"
      case .onTime: "checkmark.circle.fill"
      case .tooFastCaution: "chevron.down"
      case .tooFastWarning: "chevron.down.2"
    }
  }

  /// Classifies an arrival by direction and how far it falls from the on-time window.
  /// - Parameters:
  ///   - isLate: whether the arrival is after the time-on-target (too slow) rather than before (too
  ///     fast).
  ///   - isOnTime: whether the arrival is within the on-time window.
  ///   - isWithinCaution: whether the arrival is within the caution band (otherwise a warning).
  public init(isLate: Bool, isOnTime: Bool, isWithinCaution: Bool) {
    if isOnTime {
      self = .onTime
    } else if isLate {
      self = isWithinCaution ? .tooSlowCaution : .tooSlowWarning
    } else {
      self = isWithinCaution ? .tooFastCaution : .tooFastWarning
    }
  }

  /// Classifies `fromTo`’s projected arrival relative to `timeOnTarget`: on-time within
  /// `onTimeDeltaTOT`, and in caution within a band proportional to the nominal flight time at target
  /// speed.
  public init(
    fromTo: FromToMath,
    timeOnTarget: Date,
    onTimeDeltaTOT: Measurement<UnitDuration> = Self.runInOnTimeDeltaTOT
  ) {
    let arrival = fromTo.timeOfArrival
    let onTimeRange = (timeOnTarget - onTimeDeltaTOT)...(timeOnTarget + onTimeDeltaTOT)
    let caution = fromTo.distance / fromTo.targetSpeed * Self.speedDeviation
    let cautionRange = (timeOnTarget - caution)...(timeOnTarget + caution)
    self.init(
      isLate: fromTo.isLate,
      isOnTime: onTimeRange.contains(arrival),
      isWithinCaution: cautionRange.contains(arrival)
    )
  }
}
