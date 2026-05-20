import CoreLocation
import Foundation
import Testing

@testable import IP_Inbound

@Suite("UITestLocationProvider")
struct UITestLocationProviderTests {
  @Test("parses a rich single fix")
  func richFix() async throws {
    let info = StubProcessInfo(env: ["UITEST_LOCATION": "36.87,-115.48,1502,179,257"])
    let provider = try #require(UITestLocationProvider(processInfo: info, dateProvider: .system))
    let event = try #require(await provider.currentEvent())
    let loc = try #require(event.location)
    #expect(abs(loc.coordinate.latitude - 36.87) < 1e-6)
    #expect(abs(loc.coordinate.longitude - (-115.48)) < 1e-6)
    #expect(abs(loc.speed - 257) < 1e-6)
    #expect(abs(loc.course - 179) < 1e-6)
  }

  @Test("interpolates a scripted path against the clock")
  func scriptedPath() async throws {
    // Controllable clock: now() reads a mutable instant so simulated time can
    // be advanced deterministically without sleeping. Test-only @unchecked
    // Sendable (single-threaded: the mutation happens-before the awaited read),
    // same justified pattern as StubProcessInfo.
    final class Tick: @unchecked Sendable {
      var value: Date

      init(value: Date) { self.value = value }
    }

    let launch = Date(timeIntervalSince1970: 1_700_000_000)
    let tick = Tick(value: launch)
    let dateProvider = DateProvider(now: { tick.value }, offsetFromRealTimeSeconds: 0)

    let json = """
      [{"t":0,"lat":0,"lon":0,"crs":90,"spd":100},
       {"t":200,"lat":0,"lon":2,"crs":90,"spd":100}]
      """
    let info = StubProcessInfo(env: ["UITEST_LOCATION_PATH": json])
    let p = try #require(UITestLocationProvider(processInfo: info, dateProvider: dateProvider))

    // Advance simulated time 100 s past launch → halfway along the 0..200 segment.
    tick.value = launch.addingTimeInterval(100)
    let loc = try #require(await p.currentEvent()?.location)
    #expect(abs(loc.coordinate.longitude - 1.0) < 0.05)
    #expect(abs(loc.speed - 100) < 1e-6)
  }

  @Test("fails init when neither env var is present or JSON is malformed")
  func failable() {
    #expect(
      UITestLocationProvider(processInfo: StubProcessInfo(env: [:]), dateProvider: .system) == nil
    )
    #expect(
      UITestLocationProvider(
        processInfo: StubProcessInfo(env: ["UITEST_LOCATION_PATH": "{not json}"]),
        dateProvider: .system
      ) == nil
    )
  }
}
