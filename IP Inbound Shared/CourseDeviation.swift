import Foundation
import MeasurementKit

/// Where the aircraft lies relative to the run-in course, in the terms a course deviation indicator
/// is drawn and spoken in. Both platforms' indicators read their needle and their announcement from
/// here, so neither can adopt a convention the other doesn't share.
public struct CourseDeviation {
  /// The cross-track distance at which an indicator reaches the end of its scale.
  public static let fullScale = Measurement(value: 4, unit: UnitLength.nauticalMiles)

  /// How far the aircraft lies off the run-in course line. Positive is **right** of course — the
  /// convention `GreatCircleSegment` answers in, so a positive deviation is corrected by turning
  /// left.
  public let crossTrackDistance: Measurement<UnitLength>

  /// How far to displace the needle from center, as a fraction of its full-scale travel in
  /// `[-1, 1]`, positive to the right of the course as drawn. The course lies on the side the
  /// aircraft must steer toward, so the needle mirrors the deviation: right of course → needle left
  /// → fly left.
  public var needleOffset: Double { -clampedRatio }

  private var clampedRatio: Double {
    crossTrackDistance.clamped(to: -Self.fullScale...Self.fullScale) / Self.fullScale
  }

  /// A deviation of `crossTrackDistance` from the run-in course.
  public init(crossTrackDistance: Measurement<UnitLength>) {
    self.crossTrackDistance = crossTrackDistance
  }

  /// The deviation as VoiceOver speaks it, e.g. “1.0 NM right of course.”, or “On course.” when the
  /// aircraft sits on the line.
  ///
  /// - Parameter unit: the length unit to read the distance in.
  /// - Returns: the spoken deviation.
  public func announcement(in unit: UnitLength = .nauticalMiles) -> String {
    let distance = crossTrackDistance.magnitude.converted(to: unit)
    guard distance > .zero else { return String(localized: "On course.") }

    let formatted = distance.formatted(distanceFormatStyle)
    return crossTrackDistance > .zero
      ? String(localized: "\(formatted) right of course.")
      : String(localized: "\(formatted) left of course.")
  }
}
