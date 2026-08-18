import Foundation

/// A `Sendable` snapshot of the app clock for use in actors, value types, and other
/// non-`@MainActor` contexts. Production uses ``DateProvider/system``; UI tests use a
/// fixed offset from real time so elapsed-time math and scripted paths still advance.
struct DateProvider: Sendable {
  static let system = Self(now: { Date() }, offsetFromRealTime: .zero)

  let now: @Sendable () -> Date

  /// How far the provider's clock leads (positive) or lags (negative) wall-clock time.
  let offsetFromRealTime: Measurement<UnitDuration>

  static func offset(reference: Date, anchor: Date) -> Self {
    Self(
      now: { reference.addingTimeInterval(Date().timeIntervalSince(anchor)) },
      offsetFromRealTime: reference - anchor
    )
  }
}
