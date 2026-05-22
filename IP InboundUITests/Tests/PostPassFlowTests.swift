import CoreLocation
import XCTest

// swiftlint:disable prefer_nimble

// Deterministic post-pass flow driven by the clock+location harness:
// pinned `UITEST_NOW` past the seeded target's TOT, a static
// `UITEST_LOCATION` placed beyond the target along the run-in axis, and two
// pre-configured seed targets so the "Fly next target" button has a candidate.
final class PostPassFlowTests: BaseTestCase {

  // MARK: - Type Properties

  // Flythrough's TOT (from the harness seed). Miss-seconds in the post-pass
  // readout is `UITEST_NOW − totFlythrough`.
  private static let totFlythroughISO = "2026-05-18T18:00:00.000Z"

  // Pin `now` to 8 seconds past the seeded target's TOT — the post-pass
  // readout becomes "8 seconds late" because the harness synthesizes the
  // CLLocation's timestamp from the injected clock.
  private static let nowISO = "2026-05-18T18:00:08.000Z"

  // Static fix: ~1 nmi south of Flythrough's coordinate (36.772367, -115.453840)
  // on course 179°T at 257 m/s — past the target along the IP→target run-in
  // axis (offsetBearing = 359°T from target), 500 kn.
  private static let pastTargetFix = "36.755664,-115.453840,0,179,257"

  // MARK: - Methods

  @MainActor
  func testPostPass_ShowsPastTargetAndFliesNextTarget() throws {
    let now = try XCTUnwrap(Self.uiTestNowFormatter.date(from: Self.nowISO))

    launchWithSeededTargets(now: now, location: Self.pastTargetFix)

    let list = TargetListPage(app: app)
    XCTAssertTrue(list.isDisplayed, "Target list should appear with the seeded targets")

    _ = list.selectTarget(named: "Flythrough")

    let postPass = PostPassPage(app: app)
    if !postPass.waitUntilDisplayed(timeout: 8) {
      // `isConfigured = true` is supposed to trigger skip-to-fly; SwiftUI's
      // setup-flow `@State` sometimes preserves prior path on selection so
      // we land on the Define Target page. Tap-only walk through the
      // already-populated configured pages to reach Fly — mirrors
      // HarnessFlythroughTests's fallback. No keyboard input.
      let setup = TargetSetupPage(app: app)
      let ipPage = setup.tapDefineIP()
      let totPage = ipPage.tapTimeOnTarget()
      totPage.tapFly()
      XCTAssertTrue(
        postPass.waitUntilDisplayed(timeout: 12),
        "Post-pass screen should appear once past the target and past TOT"
      )
    }

    XCTAssertTrue(
      app.staticTexts["Flythrough"].waitForExistence(timeout: 5),
      "Post-pass screen should name the flown target"
    )

    XCTAssertTrue(postPass.missText.waitForExistence(timeout: 5))
    let missLabel = postPass.missLabel
    XCTAssertTrue(
      missLabel.localizedCaseInsensitiveContains("late"),
      "Miss text should read late (now is 8 s past TOT), got: ‘\(missLabel)’"
    )

    postPass.captureScreenshot(name: "PostPass-PastTarget-Flythrough", test: self)

    // Tap "Fly next target" — NextHop becomes the active target. SwiftUI's
    // skip-to-fly path is flakey across selections; the next target may land
    // on TargetSetupView (name in targetNameField) or directly on FlyView
    // (name as a StaticText). Either satisfies the contract that the next
    // target is now active.
    postPass.tapFlyNextTarget()

    let nextHopActive = NSPredicate(
      format: "(elementType == %d AND label == %@) OR (elementType == %d AND value == %@)",
      XCUIElement.ElementType.staticText.rawValue,
      "NextHop",
      XCUIElement.ElementType.textField.rawValue,
      "NextHop"
    )
    let nextHopElement = app.descendants(matching: .any).element(matching: nextHopActive)
    XCTAssertTrue(
      nextHopElement.waitForExistence(timeout: 15),
      "Tapping ‘Fly next target’ should make NextHop the active target"
    )

    captureNextTargetScreenshot()
  }

  // MARK: - Helpers

  @MainActor
  private func launchWithSeededTargets(now: Date, location: String) {
    let knownApps = ["codes.tim.FART"]
    for bundleID in knownApps {
      let other = XCUIApplication(bundleIdentifier: bundleID)
      if other.state != .notRunning { other.terminate() }
    }

    if UIDevice.current.userInterfaceIdiom == .pad {
      XCUIDevice.shared.orientation = .landscapeLeft
    }

    app = XCUIApplication()
    app.launchArguments.append("-UITests")
    app.launchEnvironment["UITEST_NOW"] = Self.uiTestNowFormatter.string(from: now)
    app.launchEnvironment["UITEST_LOCATION"] = location
    app.launchEnvironment["UITEST_SEED_TARGET"] = "1"
    app.launchEnvironment["UITEST_SEED_NEXT_TARGET"] = "1"
    // Preserve the seeded past TOT; the harness deliberately drives
    // post-TOT scenarios and TOTSetupView's default auto-bump would
    // overwrite it during the fallback navigation path.
    app.launchEnvironment["UITEST_BYPASS_TOT_RESET"] = "1"
    app.resetAuthorizationStatus(for: .location)
    app.launch()
    waitForAppStability()
    handleLocationPermissionIfNeeded()
  }

  // Screenshot capture on the next target's screen. Uses a generic `Page`
  // wrapper because the visible screen after "Fly next target" depends on
  // SwiftUI's navigation reset behavior — the assertion above already verified
  // the target is active; this just attaches the rendered state.
  @MainActor
  private func captureNextTargetScreenshot() {
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = "PostPass-NextTarget-NextHop"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}

// swiftlint:enable prefer_nimble
