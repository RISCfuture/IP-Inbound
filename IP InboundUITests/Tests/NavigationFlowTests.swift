import CoreLocation
import XCTest

// swiftlint:disable prefer_nimble

final class NavigationFlowTests: BaseTestCase {

  // Wait for fly view content (countdown mode expected in test environment)
  @MainActor
  private func waitForFlyContent(timeout: TimeInterval = 15) -> Bool {
    let guidanceMsg = app.staticTexts["Guidance begins once aircraft is moving."]
    if guidanceMsg.waitForExistence(timeout: timeout) { return true }
    let pposIP = app.staticTexts["P.POS → IP"]
    let ipTarget = app.staticTexts["IP → Target"]
    return pposIP.exists || ipTarget.exists
  }

  // Navigate back from fly view to the setup root.
  // iPhone: pops the SetupFlowView off the master nav stack, ending on the
  // target list. iPad: rewinds the detail panel's NavigationStack to Define
  // Target — the sidebar stays visible. Re-selecting the same cell on iPad
  // does not reset the detail (SetupFlowView is `.id`-bound to the target),
  // so the test has to drive this back-traversal explicitly.
  @MainActor
  private func navigateBackFromFly() {
    // Use `targetNameField` (only present on the root TargetSetupView, not on
    // TOT/IP/Fly) so the back loop doesn't stop early. `defineIPButton` also
    // appears on TOTSetupView as a back-to-IP link, so it's not unique enough.
    let exitMarker: XCUIElement =
      isIPad ? app.textFields["targetNameField"] : app.buttons["addTargetButton"]
    for _ in 0..<6 {
      if exitMarker.waitForExistence(timeout: 1) { break }
      let backButton = app.navigationBars.buttons.element(boundBy: 0)
      guard backButton.waitForExistence(timeout: 3) else { break }
      if backButton.isHittable {
        backButton.tap()
      } else {
        backButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
      }
      Thread.sleep(forTimeInterval: 0.5)
    }
  }

  // MARK: - Test 24

  @MainActor
  func testForwardNavigationFlow() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "NavFlow")

    let ipPage = setup.tapDefineIP()
    ipPage.enterBearing("090")
    ipPage.enterOffsetDistance("5")

    let totPage = ipPage.tapTimeOnTarget()
    totPage.selectZuluTime()
    totPage.enterTime("18:00:00")

    totPage.tapFly()

    // Assert fly view loads (countdown mode expected in test environment)
    XCTAssertTrue(waitForFlyContent(), "Fly view content should appear after forward navigation")

    // Clean up
    navigateBackFromFly()
    TargetListPage(app: app).deleteTarget(named: "NavFlow")
  }

  // Polls a text field's `value` — re-querying each tick — until it equals `expectedValue`. Avoids
  // both fixed settle sleeps and the stale-snapshot pitfalls of `XCTNSPredicateExpectation` bound
  // to an element captured mid-navigation-transition.
  @MainActor
  private func waitForFieldValue(
    _ field: @autoclosure () -> XCUIElement,
    equals expectedValue: String,
    timeout: TimeInterval = 5
  ) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if let value = field().value as? String, value == expectedValue { return true }
      RunLoop.current.run(until: Date().addingTimeInterval(0.2))
    } while Date() < deadline
    return (field().value as? String) == expectedValue
  }

  // MARK: - Test 25

  @MainActor
  func testBackNavigationFlow() throws {
    try skipOniOS18()
    launchApp()
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "BackNav")

    let ipPage = setup.tapDefineIP()
    ipPage.enterBearing("270")
    ipPage.enterOffsetDistance("3")

    // Capture the value the field actually holds before navigating away. This test verifies value
    // RETENTION across back navigation, not data-entry accuracy, so it compares against what was
    // actually entered (numeric keypad entry is flaky on the simulator) rather than a hard-coded
    // expectation.
    let enteredBearing = ipPage.offsetBearingField.value as? String ?? ""
    XCTAssertFalse(
      enteredBearing.isEmpty,
      "Bearing field should hold a value before navigating away"
    )

    let totPage = ipPage.tapTimeOnTarget()
    XCTAssertTrue(totPage.isDisplayed, "TOT page should appear")

    // Go back to IP setup
    totPage.tapBackToIPSetup()

    // Assert bearing field retains value; wait for it to repopulate after the
    // back navigation rather than sleeping a fixed interval.
    let ipBack = IPSetupPage(app: app)
    _ = ipBack.scrollToVisible(ipBack.offsetBearingField)
    XCTAssertTrue(ipBack.offsetBearingField.waitForExistence(timeout: 5))
    XCTAssertTrue(
      waitForFieldValue(ipBack.offsetBearingField, equals: enteredBearing),
      "Bearing should retain ‘\(enteredBearing)’ but was: "
        + "‘\(ipBack.offsetBearingField.value as? String ?? "")’"
    )

    // Go back to target setup via the IP Setup page's back button
    let ipBack2 = IPSetupPage(app: app)
    ipBack2.tapBackToTargetSetup()

    // Wait for the name field to repopulate with the retained value rather than
    // sleeping a fixed interval before reading it.
    let setupBack = TargetSetupPage(app: app)
    XCTAssertTrue(setupBack.targetNameField.waitForExistence(timeout: 5))
    XCTAssertTrue(
      waitForFieldValue(setupBack.targetNameField, equals: "BackNav"),
      "Target name should retain ‘BackNav’ but was: "
        + "‘\(setupBack.targetNameField.value as? String ?? "")’"
    )

    // Clean up
    if !isIPad {
      _ = setupBack.navigateBackToList()
    }
    TargetListPage(app: app).deleteTarget(named: "BackNav")
  }

  // MARK: - Test 26

  // Verifies the post-auto-advance contract: re-selecting an already-configured target from the list
  // lands on the setup flow (Define Target), not the fly view. Auto-advance to fly was removed; only
  // the post-pass “Fly <target>” shortcut jumps straight to fly.
  @MainActor
  func testConfiguredTargetLandsOnSetup() throws {
    try skipOniOS18()
    launchApp()
    let list = TargetListPage(app: app)

    // Fully configure target
    let setup = list.createTarget(named: "ConfiguredSetup")

    let ipPage = setup.tapDefineIP()
    ipPage.enterBearing("090")
    ipPage.enterOffsetDistance("5")
    ipPage.enterGroundSpeed("120")

    let totPage = ipPage.tapTimeOnTarget()
    totPage.selectZuluTime()
    totPage.enterTime("18:00:00")

    totPage.tapFly()

    // Wait for fly view to render
    XCTAssertTrue(waitForFlyContent(), "Fly view should render on first visit")

    // Navigate back to list
    navigateBackFromFly()

    // Re-select the configured target from the list.
    let listPage = TargetListPage(app: app)
    XCTAssertTrue(listPage.isDisplayed)
    listPage.selectTarget(named: "ConfiguredSetup")

    // A configured target re-selected from the list lands on the setup flow; it does not skip to fly.
    XCTAssertTrue(
      app.buttons["defineIPButton"].waitForExistence(timeout: 15),
      "Re-selecting a configured target should land on the setup flow (Define IP visible)"
    )
    XCTAssertFalse(
      app.otherElements["flyView"].exists,
      "Re-selecting a configured target must not skip to the fly view"
    )

    // Clean up
    if !isIPad {
      _ = TargetSetupPage(app: app).navigateBackToList()
    }
    TargetListPage(app: app).deleteTarget(named: "ConfiguredSetup")
  }

  // MARK: - Test 27

  @MainActor
  func testNewTargetLandsOnSetup() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "NewSetup")

    // Assert we land on target setup, NOT fly view
    XCTAssertTrue(
      setup.defineIPButton.waitForExistence(timeout: 5),
      "Define IP button should be visible"
    )

    // Verify it's NOT the fly view
    let flyView = app.otherElements["flyView"]
    XCTAssertFalse(flyView.exists, "Should NOT be on fly view for new target")

    // Clean up
    if !isIPad {
      _ = setup.navigateBackToList()
    }
    TargetListPage(app: app).deleteTarget(named: "NewSetup")
  }

  // MARK: - Test 28

  @MainActor
  func testNavigateBackFromFlyAllowsReconfig() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "Reconfig")

    let ipPage = setup.tapDefineIP()
    ipPage.enterBearing("090")
    ipPage.enterOffsetDistance("5")

    let totPage = ipPage.tapTimeOnTarget()
    totPage.selectZuluTime()
    totPage.enterTime("18:00:00")

    totPage.tapFly()
    XCTAssertTrue(waitForFlyContent(), "Fly view should render")

    // Go back to TOT via nav bar back button (labeled with previous view's title)
    let backButton = app.navigationBars.buttons["Time on Target"]
    if backButton.waitForExistence(timeout: 3) {
      if backButton.isHittable {
        backButton.tap()
      } else {
        backButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
      }
    } else {
      // Fallback: tap first nav bar back button
      let fallback = app.navigationBars.buttons.element(boundBy: 0)
      if fallback.isHittable {
        fallback.tap()
      } else {
        fallback.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
      }
    }

    // Verify we can see the TOT page (`isDisplayed` waits for the picker to
    // appear, so no fixed settle is needed).
    let totBack = TOTSetupPage(app: app)
    XCTAssertTrue(totBack.isDisplayed, "Should be on TOT page after back from fly")

    // Go back forward to fly
    totBack.tapFly()
    XCTAssertTrue(
      waitForFlyContent(),
      "Fly view should render after reconfig"
    )

    // Clean up
    navigateBackFromFly()
    TargetListPage(app: app).deleteTarget(named: "Reconfig")
  }
}

// swiftlint:enable prefer_nimble
