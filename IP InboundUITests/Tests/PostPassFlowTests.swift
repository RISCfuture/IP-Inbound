import CoreLocation
import XCTest

// swiftlint:disable prefer_nimble

final class PostPassFlowTests: BaseTestCase {

  // MARK: - Helpers

  /// The app, when launched with `-UITestPostPass`, substitutes a synthetic
  /// moving fix beyond the target so the `.postPass` guidance is reached
  /// deterministically without driving live location updates.
  @MainActor
  private func launchAppForPostPass() {
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
    app.launchArguments.append("-UITestPostPass")
    app.resetAuthorizationStatus(for: .location)
    app.launch()
    waitForAppStability()
    setSimulatedLocation(latitude: 37.7749, longitude: -122.4194)
    handleLocationPermissionIfNeeded()
    setSimulatedLocation(latitude: 37.7749, longitude: -122.4194)
  }

  /// A Zulu HHMMSS string a couple of minutes from now, so the post-pass miss
  /// reads as a small, human-scale value.
  private func soonZuluTime(minutesFromNow: Int) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let date = Date().addingTimeInterval(TimeInterval(minutesFromNow * 60))
    let components = calendar.dateComponents([.hour, .minute, .second], from: date)
    return String(
      format: "%02d%02d%02d",
      components.hour ?? 0,
      components.minute ?? 0,
      components.second ?? 0
    )
  }

  @MainActor
  @discardableResult
  private func configureTargetAndFly(named name: String, minutesToTOT: Int) -> FlyPage {
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: name)

    let ipPage = setup.tapDefineIP()
    ipPage.enterBearing("359")
    ipPage.selectBearingReference("°T")
    ipPage.enterOffsetDistance("4.8")
    ipPage.enterGroundSpeed("120")

    let totPage = ipPage.tapTimeOnTarget()
    totPage.selectZuluTime()
    totPage.enterTime(soonZuluTime(minutesFromNow: minutesToTOT))

    return totPage.tapFly()
  }

  @MainActor
  private func navigateBackToList() {
    if !isIPad {
      for _ in 0..<8 {
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

  // MARK: - Test 35

  @MainActor
  func testPostPass_ShowsResultAndFliesNextTarget() throws {
    launchAppForPostPass()

    // A later target must exist so "Fly next target" has a candidate.
    configureTargetAndFly(named: "NextHop", minutesToTOT: 12)
    let postPassForNextHop = PostPassPage(app: app)
    XCTAssertTrue(
      postPassForNextHop.isDisplayed,
      "Post-pass screen should appear for the first configured target"
    )
    navigateBackToList()

    // Fly the primary target with a near-future TOT.
    configureTargetAndFly(named: "PassTarget", minutesToTOT: 2)

    let postPass = PostPassPage(app: app)
    XCTAssertTrue(postPass.isDisplayed, "Post-pass screen should appear after overflying target")
    XCTAssertTrue(
      app.staticTexts["PassTarget"].waitForExistence(timeout: 5),
      "Post-pass screen should name the flown target"
    )

    // Miss text should be present and reference the early/late wording.
    XCTAssertTrue(
      postPass.missText.waitForExistence(timeout: 5),
      "Post-pass miss text should be displayed"
    )
    let missLabel = postPass.missLabel
    XCTAssertTrue(
      missLabel.localizedCaseInsensitiveContains("early")
        || missLabel.localizedCaseInsensitiveContains("late"),
      "Miss text should report early/late but was: '\(missLabel)'"
    )

    postPass.captureScreenshot(name: "PostPass-Result", test: self)

    // Tap "Fly next target" — the next target (NextHop) becomes the active
    // target and is flown, surfacing its own post-pass screen (the test
    // affordance is still active).
    postPass.tapFlyNextTarget()

    // The next target is now active: its name appears either as the post-pass
    // subtitle (StaticText) or in the setup-flow name field (TextField value).
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
      "The next target ‘NextHop’ should now be the active target"
    )

    // The rebuilt setup-flow subtree reconnects the location stream before
    // guidance recomputes; the configured target skips straight to fly. Mirror
    // NavigationFlowTests' resilient handling of skip-to-fly: if it does not
    // auto-advance, drive the already-configured target forward manually.
    let postPassNext = PostPassPage(app: app)
    if !postPassNext.waitUntilDisplayed(timeout: 20) {
      let setup = TargetSetupPage(app: app)
      let ipPage = setup.tapDefineIP()
      let totPage = ipPage.tapTimeOnTarget()
      totPage.tapFly()
      XCTAssertTrue(
        postPassNext.waitUntilDisplayed(timeout: 20),
        "The post-pass screen should appear for the next target ‘NextHop’"
      )
    }
    XCTAssertTrue(
      app.staticTexts["NextHop"].waitForExistence(timeout: 5),
      "The post-pass screen should name the next target ‘NextHop’"
    )

    postPassNext.captureScreenshot(name: "PostPass-NextTarget", test: self)

    // Clean up.
    postPassNext.tapChooseTarget()
    let listPage = TargetListPage(app: app)
    XCTAssertTrue(listPage.isDisplayed, "Choosing a target should return to the list")
    listPage.deleteTarget(named: "PassTarget")
    listPage.deleteTarget(named: "NextHop")
  }
}

// swiftlint:enable prefer_nimble
