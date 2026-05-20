import Foundation
import Testing

@testable import IP_Inbound

@Suite("AppServices.make")
@MainActor
struct AppServicesTests {
  @Test("not UI testing → live SystemClock + LocationStreamer")
  func live() async {
    let info = StubProcessInfo(env: [:])  // no XCTestConfigurationFilePath, no -UITests
    let services = await AppServices.make(processInfo: info)
    #expect(services.clock is SystemClock)
    #expect(services.location is LocationStreamer)
  }

  @Test("UI testing with UITEST_NOW → UITestClock")
  func uiTestClock() async {
    let info = StubProcessInfo(
      env: ["XCTestConfigurationFilePath": "/x", "UITEST_NOW": "2026-05-18T18:00:00Z"]
    )
    let services = await AppServices.make(processInfo: info)
    #expect(services.clock is UITestClock)
  }

  @Test("UI testing, UITEST_NOW missing → per-field fallback to SystemClock")
  func perFieldFallback() async {
    let info = StubProcessInfo(
      env: ["XCTestConfigurationFilePath": "/x", "UITEST_LOCATION": "1,2,0,0,0"]
    )
    let services = await AppServices.make(processInfo: info)
    #expect(services.clock is SystemClock)
    #expect(services.location is UITestLocationProvider)
  }

  @Test(
    """
    UI testing with UITEST_NOW + UITEST_LOCATION → UITestClock + UITestLocationProvider (no live \
    streamer)
    """
  )
  func uiTestFullFake() async {
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
