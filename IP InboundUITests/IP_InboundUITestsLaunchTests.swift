import CoreLocation
import XCTest

// swiftlint:disable prefer_nimble
// swiftlint:disable empty_count

final class IP_InboundUITestsLaunchTests: BaseTestCase {
  override static var runsForEachTargetApplicationUIConfiguration: Bool {
    false  // Only run once, not for each configuration
  }

  // MARK: - Launch Tests

  // Launches the app, captures a launch screenshot, and verifies the app reached its real initial
  // screen — the target list — by asserting its `addTargetButton`. A blank or crashed launch would
  // fail this assertion.
  @MainActor
  func testLaunch_ReachesTargetList() throws {
    launchApp()

    captureLaunchScreenshot()

    let list = TargetListPage(app: app)
    XCTAssertTrue(
      list.isDisplayed,
      "App should launch to the target list with its “Add Target” button"
    )
  }

  // Measures cold-launch performance so launch-time regressions surface in CI.
  @MainActor
  func testLaunchPerformance() throws {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      let app = XCUIApplication()
      app.launchArguments.append("-UITests")
      app.launch()
    }
  }

  // MARK: - Methods

  @MainActor
  private func captureLaunchScreenshot() {
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Launch Screen"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
}

// swiftlint:enable prefer_nimble
// swiftlint:enable empty_count
