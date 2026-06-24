import SwiftUI

/// How early or late an arrival is tracking against its time-on-target, paired with the readout color
/// and direction icon. Shared by the Fly timing display, the post-pass verdict, and the watch CDI so a
/// given tier always reads identically across the phone and watch.
enum TimingTier: CaseIterable, Hashable {
  case tooSlowWarning
  case tooSlowCaution
  case onTime
  case tooFastCaution
  case tooFastWarning

  /// On-time window the run-in guidance flies to: arrivals within this many seconds of the
  /// time-on-target read as on-time.
  static let runInOnTimeDeltaTOT: TimeInterval = 30

  /// Allowable deviation from target speed, as a fraction of target speed, before the arrival leaves
  /// the caution band for a warning — equivalently, the fraction of the nominal flight time that
  /// bounds the caution band.
  private static let speedDeviation = 0.1
  private static let secondsPerMinute = 60.0

  /// The bright asset color for this tier: green on-time, then the too-slow / too-fast palette in
  /// caution or warning shades.
  var color: Color {
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
  var systemImage: String {
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
  init(isLate: Bool, isOnTime: Bool, isWithinCaution: Bool) {
    if isOnTime {
      self = .onTime
    } else if isLate {
      self = isWithinCaution ? .tooSlowCaution : .tooSlowWarning
    } else {
      self = isWithinCaution ? .tooFastCaution : .tooFastWarning
    }
  }

  /// Classifies `fromTo`’s projected arrival relative to `timeOnTarget`: on-time within
  /// `onTimeDeltaTOT` seconds, and in caution within a band proportional to the nominal flight time at
  /// target speed.
  init(
    fromTo: FromToMath,
    timeOnTarget: Date,
    onTimeDeltaTOT: TimeInterval = Self.runInOnTimeDeltaTOT
  ) {
    let arrival = fromTo.timeOfArrival
    let onTimeRange =
      timeOnTarget.addingTimeInterval(
        -onTimeDeltaTOT
      )...timeOnTarget.addingTimeInterval(onTimeDeltaTOT)
    let caution = fromTo.distance / fromTo.targetSpeed * Self.speedDeviation * Self.secondsPerMinute
    let cautionRange = caution.before(date: timeOnTarget)...caution.after(date: timeOnTarget)
    self.init(
      isLate: fromTo.isLate,
      isOnTime: onTimeRange.contains(arrival),
      isWithinCaution: cautionRange.contains(arrival)
    )
  }
}
