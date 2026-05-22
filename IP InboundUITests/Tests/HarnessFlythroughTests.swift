import CoreLocation
import XCTest

// swiftlint:disable prefer_nimble

final class HarnessFlythroughTests: BaseTestCase {

  @MainActor
  func testScriptedFlythroughShowsMovingGuidance() throws {
    // TOT = 18:00:00Z; pin "now" to TOT − 30 s so the scripted path's elapsed
    // window covers the inbound portion through-and-past the target.
    let tot = Self.uiTestNowFormatter.date(from: "2026-05-18T18:00:00.000Z")!
    let now = tot.addingTimeInterval(-30)

    // Three-waypoint scripted path: pre-IP at t=0 → just past IP at t=20 →
    // over target at t=55 — heading ~179°T, ~257 m/s — matching PreviewHelper's
    // validated inbound geometry.
    let path = """
      [{"t":0,"lat":36.876930,"lon":-115.481479,"crs":179,"spd":257},
       {"t":20,"lat":36.807822,"lon":-115.484047,"crs":179,"spd":257},
       {"t":55,"lat":36.772367,"lon":-115.453840,"crs":179,"spd":257}]
      """

    // Launch with the harness-seeded target so we bypass the (environmentally
    // broken) groundSpeedField keyboard entry.
    app = XCUIApplication()
    app.launchArguments.append("-UITests")
    app.launchEnvironment["UITEST_NOW"] = Self.uiTestNowFormatter.string(from: now)
    app.launchEnvironment["UITEST_LOCATION_PATH"] = path
    app.launchEnvironment["UITEST_SEED_TARGET"] = "1"
    app.resetAuthorizationStatus(for: .location)
    app.launch()
    waitForAppStability()
    handleLocationPermissionIfNeeded()

    let list = TargetListPage(app: app)
    XCTAssertTrue(list.isDisplayed, "Target list should appear with the seeded target")
    let setupPage = list.selectTarget(named: "Flythrough")

    // `Target.isConfigured == true` should trigger skip-to-fly. If it doesn't
    // (SwiftUI sometimes preserves @State across selection), fall back to a
    // tap-only navigation to the Fly view (NO keyboard entry).
    let movingGuidance = NSPredicate(
      format: "label IN { %@, %@, %@ }",
      "P.POS → IP",
      "IP → Target",
      "P.POS → Target"
    )
    let movingLabel = app.staticTexts.matching(movingGuidance).firstMatch
    if !movingLabel.waitForExistence(timeout: 12) {
      // Fallback: tap through configured pages to Fly (no keyboard input).
      let ipPage = setupPage.tapDefineIP()
      let totPage = ipPage.tapTimeOnTarget()
      totPage.tapFly()
      XCTAssertTrue(
        movingLabel.waitForExistence(timeout: 12),
        "Moving guidance label should appear after tap-only navigation"
      )
    }

    let fly = FlyPage(app: app)

    // Capture the moving-guidance render — the proof that the harness produces
    // realistic guidance (course+speed inject correctly).
    fly.captureScreenshot(name: "Flythrough-MovingGuidance", test: self)

    // Wait for the scripted path to advance toward/over the target so the
    // deterministic seconds-early/late readout renders, rather than sleeping a
    // fixed interval. The readout's appearance is the path-advanced signal —
    // deterministic because now + path + TOT are all pinned at launch.
    let timingPredicate = NSPredicate(
      format: "label MATCHES %@",
      "(?i).*\\d+ seconds? (early|late).*"
    )
    let timingText = app.staticTexts.matching(timingPredicate).firstMatch
    XCTAssertTrue(
      timingText.waitForExistence(timeout: 12),
      "Deterministic seconds-early/late timing readout should be rendered from injected clock"
    )

    // Capture the timing readout now that the path has advanced and it is
    // on-screen.
    fly.captureScreenshot(name: "Flythrough-TimingReadout", test: self)
  }
}

// swiftlint:enable prefer_nimble
