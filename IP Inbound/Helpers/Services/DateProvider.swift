import Foundation

/// A `Sendable` snapshot of the app clock for use in actors, value types, and other
/// non-`@MainActor` contexts. Production uses ``DateProvider/system``; UI tests use a
/// fixed offset from real time so elapsed-time math and scripted paths still advance.
struct DateProvider: Sendable {
  static let system = Self(now: { Date() }, offsetFromRealTimeSeconds: 0)

  let now: @Sendable () -> Date
  let offsetFromRealTimeSeconds: Int

  static func offset(reference: Date, anchor: Date) -> Self {
    Self(
      now: { reference.addingTimeInterval(Date().timeIntervalSince(anchor)) },
      offsetFromRealTimeSeconds: Int(reference.timeIntervalSince(anchor).rounded())
    )
  }
}
