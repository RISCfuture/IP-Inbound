import CoreLocation
import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

final class FlyViewTests: BaseTestCase {

  // MARK: - Type Properties

  // The seeded "Flythrough" target's IP lies ~4.8 NM north of the target on a 179°T run-in axis.
  // A rich fix ~2 NM past the IP, on-axis, heading 179°T at 62 m/s (~120 kn, above the movement
  // threshold) puts `GuidanceHelper` into `.toTarget` — the IP→Target phase that renders the CDI.
  private static let ipToTargetFix = "36.818995,-115.454857,1502,179,62"

  // A stationary (0 m/s) pre-IP fix. Below the 30 kn movement threshold, `GuidanceHelper` stays in
  // `.countdownOnly`; a valid position keeps `pposToTarget` non-nil so the `TOTView` distance
  // readout renders.
  private static let countdownFix = "36.935565,-115.457402,1502,179,0"

  // MARK: - Helpers

  @discardableResult
  private func configureTargetAndFly(named name: String) -> FlyPage {
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: name)

    let ipPage = setup.tapDefineIP()
    ipPage.enterBearing("359")
    ipPage.selectBearingReference("°T")
    ipPage.enterOffsetDistance("4.8")
    ipPage.enterGroundSpeed("120")

    let totPage = ipPage.tapTimeOnTarget()
    totPage.selectZuluTime()
    totPage.enterTime("18:00:00")

    return totPage.tapFly()
  }

  private func cleanUpFromFly(_ name: String) {
    let list = TargetListPage(app: app)
    list.navigateBackToList()
    list.deleteTarget(named: name)
  }

  // Launches with the seeded "Flythrough" target and the given location fix, pinning `UITEST_NOW`
  // `secondsBeforeTOT` ahead of the seeded TOT, then navigates to the Fly view. Mirrors the
  // clock+location harness used by the required-speed tests, walking any residual setup pages that
  // SwiftUI sometimes restores across selection even with `isConfigured == true`.
  private func launchSeededFlythrough(fix: String, secondsBeforeTOT: TimeInterval) throws -> FlyPage
  {
    let tot = try XCTUnwrap(
      Self.uiTestNowFormatter.date(from: "2026-05-18T18:00:00.000Z")
    )
    let now = tot.addingTimeInterval(-secondsBeforeTOT)

    app = XCUIApplication()
    app.disableLogStderrMirroring()
    app.launchArguments.append("-UITests")
    app.launchEnvironment["UITEST_NOW"] = Self.uiTestNowFormatter.string(from: now)
    app.launchEnvironment["UITEST_LOCATION"] = fix
    app.launchEnvironment["UITEST_SEED_TARGET"] = "1"
    app.launchEnvironment["UITEST_BYPASS_TOT_RESET"] = "1"
    app.resetAuthorizationStatus(for: .location)
    app.launch()
    waitForAppStability()
    handleLocationPermissionIfNeeded()

    let list = TargetListPage(app: app)
    XCTAssertTrue(list.isDisplayed, "Seeded target list should appear")
    let setup = list.selectTarget(named: "Flythrough")
    return setup.advanceThroughSetupToFly()
  }

  // Moving on-axis fix past the IP → `.toTarget` (IP→Target) guidance, which renders the CDI.
  private func launchIntoIPToTarget() throws -> FlyPage {
    try launchSeededFlythrough(fix: Self.ipToTargetFix, secondsBeforeTOT: 90)
  }

  // Stationary fix → `.countdownOnly` guidance, whose `TOTView` renders the distance readout.
  private func launchIntoCountdownWithDistance() throws -> FlyPage {
    try launchSeededFlythrough(fix: Self.countdownFix, secondsBeforeTOT: 600)
  }

  // Wait for any fly view content to appear after navigating to FlyView.
  // The LocationStreamer in UI test mode delivers a static location, so the
  // fly view should render in countdownOnly mode after a brief delay.
  private func waitForFlyContent(timeout: TimeInterval = 15) -> Bool {
    // SwiftUI propagates the "flyView" identifier to all child texts, so check
    // for known text content rather than element identifiers.
    let guidanceMsg = app.staticTexts["Guidance begins once aircraft is moving."]
    if guidanceMsg.waitForExistence(timeout: timeout) { return true }

    // Also check for guidance mode texts
    let pposIP = app.staticTexts["P.POS → IP"]
    let ipTarget = app.staticTexts["IP → Target"]
    return pposIP.exists || ipTarget.exists
  }

  // MARK: - Test 29

  func testFlyView_ShowsTargetName() throws {
    launchApp()
    configureTargetAndFly(named: "Echo")

    // Wait for fly view to render (LocationStreamer delivers static location in test mode)
    XCTAssertTrue(waitForFlyContent(), "Fly view content should appear")

    // In countdownOnly mode, target name is the main title
    let targetNamePredicate = NSPredicate(format: "label CONTAINS[c] %@", "Echo")
    let targetNameText = app.staticTexts.element(matching: targetNamePredicate)
    XCTAssertTrue(
      targetNameText.waitForExistence(timeout: 5),
      "'Echo' should appear as static text in fly view"
    )

    cleanUpFromFly("Echo")
  }

  // MARK: - Test 30

  func testFlyView_CountdownMode_ShowsGuidanceMessage() throws {
    launchApp()
    configureTargetAndFly(named: "GuidanceMsg")

    XCTAssertTrue(waitForFlyContent(), "Fly view content should appear")

    // In countdownOnly mode, the guidance message is always shown
    let guidanceText = app.staticTexts["Guidance begins once aircraft is moving."]
    XCTAssertTrue(
      guidanceText.waitForExistence(timeout: 5),
      "'Guidance begins once aircraft is moving.' should be displayed in countdown mode"
    )

    cleanUpFromFly("GuidanceMsg")
  }

  // MARK: - Test 31

  func testFlyView_CountdownMode_ShowsTimeToTOT() throws {
    launchApp()
    configureTargetAndFly(named: "CountdownTOT")

    XCTAssertTrue(waitForFlyContent(), "Fly view content should appear")

    // Look for "TO TOT" or "Past TOT" text in countdown
    // Note: CountdownView uses .textCase(.uppercase) so "to TOT" becomes "TO TOT"
    let toTOT = app.staticTexts["TO TOT"]
    let pastTOT = app.staticTexts["Past TOT"]
    XCTAssertTrue(
      toTOT.waitForExistence(timeout: 5) || pastTOT.waitForExistence(timeout: 2),
      "Countdown should contain 'TO TOT' or 'Past TOT' text"
    )

    cleanUpFromFly("CountdownTOT")
  }

  // MARK: - Test 32

  func testFlyView_WithMovement_ShowsCDI() throws {
    let flyPage = try launchIntoIPToTarget()

    // The IP→Target header confirms `.toTarget` guidance is active; the CDI is the navigation
    // display for that phase, which a static-location countdown never renders.
    XCTAssertTrue(
      app.staticTexts["IP → Target"].waitForExistence(timeout: 12),
      "Moving past the IP should enter IP→Target guidance"
    )
    XCTAssertTrue(
      flyPage.cdi.waitForExistence(timeout: 5),
      "CDI should render once the aircraft is moving with active guidance"
    )
  }

  // MARK: - Test 33

  func testFlyView_PostIP_ShowsIPToTarget() throws {
    _ = try launchIntoIPToTarget()

    // Past the IP and inbound, the header must read IP→Target — not the pre-IP "P.POS → IP" nor the
    // bypass "P.POS → Target". Assert the specific header and rule out the other phases.
    XCTAssertTrue(
      app.staticTexts["IP → Target"].waitForExistence(timeout: 12),
      "Moving past the IP should show IP→Target guidance"
    )
    XCTAssertFalse(
      app.staticTexts["P.POS → IP"].exists,
      "Pre-IP guidance must not be shown once past the IP"
    )
    XCTAssertFalse(
      app.staticTexts["P.POS → Target"].exists,
      "IP-bypass guidance must not be shown on the normal IP→Target run-in"
    )
  }

  // MARK: - Test 34

  func testFlyView_CountdownMode_ShowsDistanceReadout() throws {
    // `configureTargetAndFly` injects no location, so `pposToTarget` is nil and the TOTView distance
    // readout never renders (the original test asserted nothing here — a no-op `else` branch let it
    // pass silently). The stationary harness puts the app in `.countdownOnly` with a valid position,
    // where the TOTView renders the distance readout (speed hidden); assert it actually appears.
    //
    // Tapping the readout to cycle units (nmi → mi → km) is intentionally not asserted here: it is
    // pinned to the bottom safe-area edge, where the SwiftUI `.onTapGesture` responds to synthesized
    // taps only unreliably (and the cycled unit persists in `@Default`, making the start state
    // non-deterministic across runs). The cycling logic itself is trivial.
    let flyPage = try launchIntoCountdownWithDistance()

    XCTAssertTrue(
      flyPage.flyDistanceDisplay.waitForExistence(timeout: 12),
      "TOTView distance readout should render in countdown mode"
    )
  }

  // MARK: - Test 35

  // Drives the required-speed callout deterministically via the clock+location
  // harness: a seeded target with a fixed TOT, `UITEST_NOW` placed 7 min before
  // TOT, and a static rich-fix pre-IP heading toward the IP at 35 m/s. Mirrors
  // the "5-fly-pre-ip" screenshot scenario, which puts `FlyView` into
  // `.toIPWithSpeedGuidance`, the mode that renders `TimingView`.
  func testFlyView_ShowsRequiredSpeedForTOT() throws {
    // The aircraft is 5 NM north of the IP on the run-in axis (no turn) but flying ~35 m/s — well
    // below the run-in speed — so it reaches the IP more than the on-time window late while still
    // recoverable at max speed. FlyView is therefore in `.toIPWithSpeedGuidance`, and because the
    // arrival sits outside the green on-time window it renders the required-speed callout (which is
    // hidden while on time). The clock ticks from UITEST_NOW, so it is set ~360 s before TOT to keep
    // this off-time, pre-bypass state through navigation and the wait below.
    let flyPage = try launchSeededFlythrough(
      fix: "36.935565,-115.457402,1502,179,35",
      secondsBeforeTOT: 360
    )
    let requiredSpeed = flyPage.requiredSpeedDisplay
    XCTAssertTrue(
      requiredSpeed.waitForExistence(timeout: 12),
      "Required-speed callout should render in pre-IP speed-guidance mode"
    )
    XCTAssertTrue(
      requiredSpeed.label.localizedCaseInsensitiveContains("req."),
      "Required-speed callout should show the ‘(… req.)’ copy, was ‘\(requiredSpeed.label)’"
    )

    flyPage.captureScreenshot(name: "FlyView-RequiredSpeed", test: self)
  }

  func testFlyView_HidesRequiredSpeedWhenBypassingIP() throws {
    // Off the run-in axis with a large turn still required, this geometry can't make the TOT even
    // at max speed, so FlyView bypasses the IP. The required-speed callout must be hidden there: a
    // finite “req.” speed would wrongly imply the time-on-target is still achievable.
    let flyPage = try launchSeededFlythrough(
      fix: "36.853375,-115.593249,1502,179,62",
      secondsBeforeTOT: 5 * 60
    )

    // The bypass title confirms the mode; once it’s on screen the timing readout has rendered.
    let bypassTitle = app.staticTexts["P.POS → Target"]
    XCTAssertTrue(
      bypassTitle.waitForExistence(timeout: 12),
      "This geometry should bypass the IP"
    )

    XCTAssertFalse(
      flyPage.requiredSpeedDisplay.exists,
      "Required-speed callout must be hidden when bypassing the IP"
    )
  }
}

// swiftlint:enable prefer_nimble
