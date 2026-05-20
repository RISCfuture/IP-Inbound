import Foundation
import Observation

/// The app clock. `@MainActor`-isolated for view consumption; exposes a `Sendable`
/// ``DateProvider`` for actor and value-type contexts.
@MainActor
protocol ClockProviding: AnyObject, Observable {
  var now: Date { get }
  var offsetFromRealTimeSeconds: Int { get }
  nonisolated var dateProvider: DateProvider { get }
}

/// Production clock: real wall-clock time, zero offset.
@MainActor
@Observable
final class SystemClock: ClockProviding {
  nonisolated let dateProvider = DateProvider.system

  var now: Date { Date() }
  var offsetFromRealTimeSeconds: Int { 0 }
}

/// UI-test clock: follows real time at a fixed offset so the pinned instant is
/// `UITEST_NOW` at launch. Failable — callers fall back to ``SystemClock``.
@MainActor
@Observable
final class UITestClock: ClockProviding {
  private static let envKey = "UITEST_NOW"

  nonisolated let dateProvider: DateProvider
  var now: Date { dateProvider.now() }
  var offsetFromRealTimeSeconds: Int { dateProvider.offsetFromRealTimeSeconds }

  init?(processInfo: ProcessInfo = .processInfo) {
    guard let raw = processInfo.environment[Self.envKey],
      let parsed = Self.parse(raw)
    else { return nil }
    dateProvider = .offset(reference: parsed, anchor: Date())
  }

  private static func parse(_ value: String) -> Date? {
    let withFractional = ISO8601DateFormatter()
    withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = withFractional.date(from: value) { return date }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: value)
  }
}
