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

  // Navigate back from fly view to list using nav bar back buttons
  @MainActor
  private func navigateBackFromFly() {
    if !isIPad {
      for _ in 0..<6 {
        let addTarget = app.buttons["addTargetButton"]
        if addTarget.waitForExistence(timeout: 1) { break }
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

  // Strictly verifies the skip-to-fly contract: re-selecting an already-configured target from the
  // list lands directly on the Fly screen, bypassing the setup flow (no manual-navigation
  // fallback). If skip-to-fly silently regresses, this test must fail.
  @MainActor
  func testConfiguredTargetSkipsToFly() throws {
    try skipOniOS18()
    launchApp()
    let list = TargetListPage(app: app)

    // Fully configure target
    let setup = list.createTarget(named: "SkipToFly")

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
    listPage.selectTarget(named: "SkipToFly")

    // STRICT: a configured target skips straight to Fly, bypassing the setup flow.
    XCTAssertTrue(
      waitForFlyContent(timeout: 15),
      "Selecting a configured target must skip directly to the fly view"
    )
    XCTAssertFalse(
      app.buttons["defineIPButton"].exists,
      "Skip-to-fly must bypass the setup flow (Define IP button should not appear)"
    )

    // Clean up
    navigateBackFromFly()
    TargetListPage(app: app).deleteTarget(named: "SkipToFly")
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
