import Foundation
import Testing

@testable import IP_Inbound

@Suite("ClockProviding")
@MainActor
struct ClockProvidingTests {
  @Test("SystemClock has zero offset and tracks wall time")
  func systemClock() {
    let clock = SystemClock()
    #expect(clock.offsetFromRealTimeSeconds == 0)
    #expect(abs(clock.now.timeIntervalSinceNow) < 1)
    #expect(clock.dateProvider.offsetFromRealTimeSeconds == 0)
  }

  @Test("UITestClock parses ISO-8601 and reports a stable offset")
  func uiTestClockParsesAndOffsets() throws {
    let target = Date(timeIntervalSince1970: 1_700_000_000)  // fixed past instant
    let iso = ISO8601DateFormatter().string(from: target)
    let info = StubProcessInfo(env: ["UITEST_NOW": iso])
    let clock = try #require(UITestClock(processInfo: info))

    // Time-independent invariant: now() − wallNow == offset, at any later instant.
    #expect(abs(clock.now.timeIntervalSinceNow - Double(clock.offsetFromRealTimeSeconds)) < 2)
    // Target is far in the past → large negative offset.
    #expect(clock.offsetFromRealTimeSeconds < 0)
    // The Sendable snapshot agrees with the clock.
    #expect(clock.dateProvider.offsetFromRealTimeSeconds == clock.offsetFromRealTimeSeconds)
    #expect(abs(clock.dateProvider.now().timeIntervalSince(clock.now)) < 1)
  }

  @Test("UITestClock parses fractional ISO-8601 and honors sub-seconds")
  func uiTestClockFractional() throws {
    let raw = "2026-05-18T18:00:00.500Z"
    let info = StubProcessInfo(env: ["UITEST_NOW": raw])
    let clock = try #require(UITestClock(processInfo: info))
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let expected = try #require(formatter.date(from: raw))
    // now() − wallNow == expected − wallNow == offset; proves the .500s was parsed.
    #expect(abs(clock.now.timeIntervalSinceNow - expected.timeIntervalSinceNow) < 2)
  }

  @Test("UITestClock fails init when env var missing or unparseable")
  func uiTestClockFailable() {
    #expect(UITestClock(processInfo: StubProcessInfo(env: [:])) == nil)
    #expect(UITestClock(processInfo: StubProcessInfo(env: ["UITEST_NOW": "not-a-date"])) == nil)
  }
}

final class StubProcessInfo: ProcessInfo, @unchecked Sendable {
  private let env: [String: String]
  override var environment: [String: String] { env }

  init(env: [String: String]) {
    self.env = env
    super.init()
  }
}
