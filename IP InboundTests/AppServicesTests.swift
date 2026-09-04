import Foundation
import Testing

@testable import IP_Inbound

@Suite
@MainActor
struct `AppServices.make` {
  @Test
  func `not UI testing → live SystemClock + LocationStreamer`() async {
    let info = StubProcessInfo(env: [:])  // no XCTestConfigurationFilePath, no -UITests
    let services = await AppServices.make(processInfo: info)
    #expect(services.clock is SystemClock)
    #expect(services.location is LocationStreamer)
  }

  @Test
  func `UI testing with UITEST_NOW → UITestClock`() async {
    let info = StubProcessInfo(
      env: ["XCTestConfigurationFilePath": "/x", "UITEST_NOW": "2026-05-18T18:00:00Z"]
    )
    let services = await AppServices.make(processInfo: info)
    #expect(services.clock is UITestClock)
  }

  @Test
  func `UI testing, UITEST_NOW missing → per-field fallback to SystemClock`() async {
    let info = StubProcessInfo(
      env: ["XCTestConfigurationFilePath": "/x", "UITEST_LOCATION": "1,2,0,0,0"]
    )
    let services = await AppServices.make(processInfo: info)
    #expect(services.clock is SystemClock)
    #expect(services.location is UITestLocationProvider)
  }

  @Test
  func `UITEST_NOW and UITEST_LOCATION replace both the clock and the live streamer`() async {
    let info = StubProcessInfo(
      env: [
        "XCTestConfigurationFilePath": "/x",
        "UITEST_NOW": "2026-05-18T18:00:00Z",
        "UITEST_LOCATION": "36.87,-115.48,1502,179,257"
      ]
    )
    let services = await AppServices.make(processInfo: info)
    #expect(services.clock is UITestClock)
    #expect(services.location is UITestLocationProvider)
  }
}
