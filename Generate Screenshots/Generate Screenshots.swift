// swiftlint:disable prefer_nimble
// swiftline:disable empty_count

import CoreLocation
import XCTest
import XCUITestKit

@MainActor
final class Generate_Screenshots: XCTestCase {

  // MARK: - Type Properties

  /// Anchor for the harness-pinned clock. The seeded target's `timeOnTarget`
  /// is this instant; each scenario picks `UITEST_NOW` relative to it.
  private static let seedTOTISO = "2026-05-18T18:00:00.000Z"

  /// User-facing target name for the seeded primary target. Overrides the
  /// harness default ("Flythrough") with a realistic place name so the tutorial
  /// screenshots match the makeTarget walkthrough's "Dog Bone Lake".
  private static let seedTargetName = "Dog Bone Lake"

  /// `UITEST_LOCATION` rich-fix strings: `lat,lon,alt,courseTrue,speed`.
  private static let
    targetFix = "36.772367,-115.453840,1060,0,0",
    groundFix = "36.2362,-115.0342556,570,29,0",
    preIPFix = "36.853375,-115.593249,1502,179,62",
    postIPFix = "36.80782,-115.484047,1502,179,62",
    pastTargetFix = "36.755664,-115.453840,0,179,257"

  // MARK: - Type Methods

  private static func iso(offsetMinutes: Int) -> String {
    iso(offsetSeconds: offsetMinutes * 60)
  }

  private static func iso(offsetSeconds: Int) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let base = formatter.date(from: seedTOTISO) else {
      preconditionFailure("Invalid seedTOTISO: \(seedTOTISO)")
    }
    return formatter.string(from: base.addingTimeInterval(TimeInterval(offsetSeconds)))
  }

  // MARK: - XCTestCase

  override func setUpWithError() throws {
    try super.setUpWithError()
    continueAfterFailure = false
  }

  override func tearDownWithError() throws {  // swiftlint:disable:this empty_xctest_method
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  // MARK: - Tests

  /// Setup-flow snapshots (0/1/2). Walks the addTarget → defineIP → TOT-entry
  /// pages. Pins `UITEST_LOCATION` to the target's coordinate so
  /// `NewTargetButton.resolvedCoordinate` captures it; no seeded target, so the
  /// initial target list is empty.
  @MainActor
  func testScreenshots_setup() throws {
    let app = launchHarness(now: nil, locationFix: Self.targetFix, seedTarget: false)
    makeTarget(app: app, screenshot: true)
    setTimeEntry(app: app, minutesFromNow: 30)
    snapshot("2-define-tot")
    app.terminate()
  }

  @MainActor
  func testScreenshots_ground() throws {
    let app = launchHarnessAndOpenFlyView(
      now: Self.iso(offsetMinutes: -30),
      locationFix: Self.groundFix
    )
    Thread.sleep(forTimeInterval: 3.0)
    snapshot("3-fly-ground")
    app.terminate()
  }

  @MainActor
  func testScreenshots_ipEarly() throws {
    let app = launchHarnessAndOpenFlyView(
      now: Self.iso(offsetMinutes: -15),
      locationFix: Self.preIPFix
    )
    Thread.sleep(forTimeInterval: 3.0)
    snapshot("4-fly-pre-ip-early")
    app.terminate()
  }

  @MainActor
  func testScreenshots_ip() throws {
    let app = launchHarnessAndOpenFlyView(
      now: Self.iso(offsetMinutes: -7),
      locationFix: Self.preIPFix
    )
    Thread.sleep(forTimeInterval: 3.0)
    snapshot("5-fly-pre-ip")
    app.terminate()
  }

  @MainActor
  func testScreenshots_ipLate() throws {
    let app = launchHarnessAndOpenFlyView(
      now: Self.iso(offsetMinutes: -3),
      locationFix: Self.preIPFix
    )
    Thread.sleep(forTimeInterval: 3.0)
    snapshot("6-fly-pre-ip-late")
    app.terminate()
  }

  @MainActor
  func testScreenshots_postIP() throws {
    let app = launchHarnessAndOpenFlyView(
      now: Self.iso(offsetMinutes: -2),
      locationFix: Self.postIPFix
    )
    Thread.sleep(forTimeInterval: 3.0)
    snapshot("7-fly-post-ip")
    app.terminate()
  }

  @MainActor
  func testScreenshots_postPass() throws {
    let app = launchHarnessAndOpenFlyView(
      now: Self.iso(offsetSeconds: 8),
      locationFix: Self.pastTargetFix,
      seedNextTarget: true
    )
    let pastTargetTitle = app.staticTexts["Past Target"]
    XCTAssertTrue(
      pastTargetTitle.waitForExistence(timeout: 15),
      "Post-pass view should appear once past target + past TOT"
    )
    Thread.sleep(forTimeInterval: 1.0)
    snapshot("8-post-pass")
    app.terminate()
  }

  // MARK: - Methods

  /// Launches the app under the UI-test harness: pinned `UITEST_NOW` (optional),
  /// rich-fix `UITEST_LOCATION`, and optionally one or two seeded configured
  /// targets. Handles the location-permission alert and the Apple Intelligence
  /// banner before returning.
  @MainActor
  private func launchHarness(
    now: String?,
    locationFix: String,
    seedTarget: Bool = true,
    seedNextTarget: Bool = false
  ) -> XCUIApplication {
    let app = XCUIApplication()
    setupSnapshot(app, waitForAnimations: true)
    app.launchArguments.append("-UITests")
    if let now {
      app.launchEnvironment["UITEST_NOW"] = now
    }
    app.launchEnvironment["UITEST_LOCATION"] = locationFix
    if seedTarget {
      app.launchEnvironment["UITEST_SEED_TARGET"] = "1"
      app.launchEnvironment["UITEST_SEED_TARGET_NAME"] = Self.seedTargetName
    }
    if seedNextTarget { app.launchEnvironment["UITEST_SEED_NEXT_TARGET"] = "1" }
    app.launchEnvironment["UITEST_BYPASS_TOT_RESET"] = "1"
    // Opt back into MapKit rendering — the production UI-test default
    // (`MapPlaceholder`) keeps non-screenshot tests quiescent, but the
    // tutorial screenshots need the real satellite map.
    app.launchEnvironment["UITEST_RENDER_MAPS"] = "1"
    app.resetAuthorizationStatus(for: .location)
    app.launch()

    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    if springboard.alerts.buttons["Allow While Using App"].waitForExistence(timeout: 5) {
      springboard.alerts.buttons["Allow While Using App"].tap()
    }

    // wait for Apple Intelligence banner to self-dismiss
    _ = app.textFields["nonexistent"].waitForExistence(timeout: 10)

    return app
  }

  /// Launches via the harness with a seeded target, taps `Flythrough`, and
  /// drives any residual setup pages so the test lands on FlyView (or the
  /// post-pass view when `guidance == .postPass`). Mirrors the fallback in
  /// `PostPassFlowTests` for SwiftUI's occasional setup-path restore.
  @MainActor
  private func launchHarnessAndOpenFlyView(
    now: String?,
    locationFix: String,
    seedNextTarget: Bool = false
  ) -> XCUIApplication {
    let app = launchHarness(
      now: now,
      locationFix: locationFix,
      seedTarget: true,
      seedNextTarget: seedNextTarget
    )

    let seededTarget = app.staticTexts[Self.seedTargetName]
    XCTAssertTrue(seededTarget.waitForExistence(timeout: 10), "Seeded target should appear")
    seededTarget.tap()

    if app.buttons["defineIPButton"].waitForExistence(timeout: 2) {
      app.buttons["defineIPButton"].tap()
    }
    if app.buttons["timeOnTargetButton"].waitForExistence(timeout: 2) {
      app.buttons["timeOnTargetButton"].tap()
    }
    if app.buttons["flyButton"].waitForExistence(timeout: 2) {
      app.buttons["flyButton"].tap()
    }

    return app
  }

  private func makeTarget(app: XCUIApplication, screenshot: Bool = false) {
    // `UITEST_LOCATION` (set by the harness) is the target's intended
    // coordinate, so `NewTargetButton.resolvedCoordinate` captures it here.
    app.buttons["addTargetButton"].tap()

    let targetNameField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["targetNameField"]
    )!
    clearAndTypeText(in: targetNameField, text: "Dog Bone Lake", app: app)

    Thread.sleep(forTimeInterval: 0.5)

    if screenshot { snapshot("0-define-target") }

    app.buttons["defineIPButton"].tap()

    let offsetBearingField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetBearingField"]
    )!
    XCTAssertTrue(
      offsetBearingField.waitForExistence(timeout: 2),
      "Offset bearing field should exist"
    )
    clearAndTypeText(in: offsetBearingField, text: "\(Int(LocationHelper.IPBearingTrue))", app: app)

    app.buttons["offsetBearingTrue"].tap()

    let offsetDistanceField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetDistanceField"]
    )!
    clearAndTypeText(in: offsetDistanceField, text: "\(LocationHelper.IPDistanceNM)", app: app)

    let groundSpeedField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["groundSpeedField"]
    )
    if let groundSpeedField {
      clearAndTypeText(in: groundSpeedField, text: "\(LocationHelper.targetGroundSpeed)", app: app)
    }

    Thread.sleep(forTimeInterval: 0.5)

    if screenshot { snapshot("1-define-ip") }

    app.buttons["timeOnTargetButton"].tap()
  }

  private func setTimeEntry(app: XCUIApplication, minutesFromNow: Double) {
    XCTAssertTrue(
      app.segmentedControls["timeDisplayModePicker"]
        .waitForExistence(timeout: 2),
      "Time mode picker should appear"
    )

    app.segmentedControls["timeDisplayModePicker"].buttons["Target Local"].tap()

    let now = Date()
    let targetTime = now.addingTimeInterval(minutesFromNow * 60)
    let calendar = Calendar.current
    var components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: targetTime
    )
    components.second = 0
    let roundedTargetTime = calendar.date(from: components) ?? targetTime

    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    formatter.timeZone = TimeZone.current
    let timeString = formatter.string(from: roundedTargetTime)

    enterDigits(app: app, digits: timeString)

    Thread.sleep(forTimeInterval: 1)
  }

  @MainActor
  private func clearAndTypeText(in textField: XCUIElement, text: String, app _: XCUIApplication) {
    textField.tap()
    Thread.sleep(forTimeInterval: 0.2)
    textField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
    Thread.sleep(forTimeInterval: 0.1)
    textField.typeText(text + "\n")
  }

  @MainActor
  private func enterDigits(app: XCUIApplication, digits: String) {
    for digit in digits {
      if digit.isNumber || digit.isLetter {
        app.buttons["keypad-\(digit)"].tap()
        Thread.sleep(forTimeInterval: 0.1)
      }
    }
  }
}

// swiftlint:enable prefer_nimble
// swiftline:enable empty_count
