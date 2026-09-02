import CoreLocation
import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

final class HarnessFlythroughTests: BaseTestCase {

  func testScriptedFlythroughShowsMovingGuidance() async throws {
    // TOT = 18:00:00Z; pin "now" to TOT − 30 s so the aircraft is inbound and behind its planned
    // time from the first fix, which is what puts a timing readout on screen straight away.
    let tot = Self.uiTestNowFormatter.date(from: "2026-05-18T18:00:00.000Z")!
    let now = tot.addingTimeInterval(-30)

    // Three-waypoint scripted path over the same inbound geometry PreviewHelper validates —
    // heading ~179°T, reporting ~257 m/s — but walked at a twelfth of the pace.
    //
    // The positions and reported course and speed are what the guidance math reads, so stretching
    // only the schedule leaves the guidance identical while keeping the aircraft inbound for
    // eleven minutes instead of fifty-five seconds. That matters because this runs on CI hardware
    // an order of magnitude slower than a developer machine — single tests in this suite have
    // taken over four minutes — and on the original schedule the aircraft flew past the target
    // long before the assertions below ran, leaving the post-pass screen, which has no timing
    // readout to find.
    let path = """
      [{"t":0,"lat":36.876930,"lon":-115.481479,"crs":179,"spd":257},
       {"t":240,"lat":36.807822,"lon":-115.484047,"crs":179,"spd":257},
       {"t":660,"lat":36.772367,"lon":-115.453840,"crs":179,"spd":257}]
      """

    // Launch with the harness-seeded target so we bypass the (environmentally
    // broken) groundSpeedField keyboard entry.
    app = XCUIApplication()
    app.disableLogStderrMirroring()
    app.launchArguments.append("-UITests")
    app.launchEnvironment["UITEST_NOW"] = Self.uiTestNowFormatter.string(from: now)
    app.launchEnvironment["UITEST_LOCATION_PATH"] = path
    app.launchEnvironment["UITEST_SEED_TARGET"] = "1"
    app.resetAuthorizationStatus(for: .location)
    app.launch()
    waitForAppStability()
    await handleLocationPermissionIfNeeded()

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
      let totPage = await ipPage.tapTimeOnTarget()
      await totPage.tapFly()
      XCTAssertTrue(
        movingLabel.waitForExistence(timeout: 12),
        "Moving guidance label should appear after tap-only navigation"
      )
    }

    let fly = FlyPage(app: app)

    // Capture the moving-guidance render — the proof that the harness produces
    // realistic guidance (course+speed inject correctly).
    fly.captureScreenshot(name: "Flythrough-MovingGuidance", test: self)

    // Wait for the timing readout, rather than sleeping a fixed interval: its appearance is the
    // path-advanced signal, deterministic because now, path and TOT are all pinned at launch.
    //
    // The unit is not pinned, though. The readout prints a single largest field, so the same
    // deterministic offset reads "25 seconds late" close to the planned time and "4 minutes late"
    // further from it, and which one is on screen depends on how far the path has advanced by the
    // time the runner arrives. Accepting either keeps what this asserts — that the injected clock
    // drives a deterministic early/late readout — without racing the schedule for a wording.
    let timingPredicate = NSPredicate(
      format: "label MATCHES %@",
      "(?i).*\\d+ (seconds?|minutes?)(, \\d+ seconds?)? (early|late).*"
    )
    let timingText = app.staticTexts.matching(timingPredicate).firstMatch
    XCTAssertTrue(
      timingText.waitForExistence(timeout: 30),
      "Deterministic early/late timing readout should be rendered from injected clock"
    )

    // Capture the timing readout now that the path has advanced and it is
    // on-screen.
    fly.captureScreenshot(name: "Flythrough-TimingReadout", test: self)
  }
}

// swiftlint:enable prefer_nimble
