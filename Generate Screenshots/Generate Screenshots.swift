// swiftlint:disable prefer_nimble
// swiftline:disable empty_count

import CoreLocation
import XCTest

@MainActor
final class Generate_Screenshots: XCTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    continueAfterFailure = false
  }

  override func tearDownWithError() throws {  // swiftlint:disable:this empty_xctest_method
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  @MainActor
  func testScreenshots_ground() throws {
    let app = launch()

    makeTarget(app: app, screenshot: true)

    setTimeEntry(app: app, minutesFromNow: 30)  // Ground location - just shows countdown
    snapshot("2-define-tot")

    XCUIDevice.shared.location = .init(location: LocationHelper.groundLocation())

    let flyButton = app.buttons["flyButton"]
    XCTAssertTrue(flyButton.waitForExistence(timeout: 10), "Fly button should exist")
    flyButton.tap()

    // Wait for countdown to appear
    Thread.sleep(forTimeInterval: 3.0)

    snapshot("3-fly-ground")

    app.terminate()
  }

  @MainActor
  func testScreenshots_ipEarly() throws {
    let app = launch()

    makeTarget(app: app)
    setTimeEntry(app: app, minutesFromNow: 15)  // Early - shows route via IP with time to spare

    XCUIDevice.shared.location = .init(location: LocationHelper.preIPLocation())
    let flyButton = app.buttons["flyButton"]
    XCTAssertTrue(flyButton.waitForExistence(timeout: 10), "Fly button should exist")
    flyButton.tap()
    Thread.sleep(forTimeInterval: 3.0)

    snapshot("4-fly-pre-ip-early")

    app.terminate()
  }

  @MainActor
  func testScreenshots_ip() throws {
    let app = launch()

    makeTarget(app: app)
    setTimeEntry(app: app, minutesFromNow: 6)  // On-time - should show route via IP with speed guidance

    XCUIDevice.shared.location = .init(location: LocationHelper.preIPLocation())
    let flyButton = app.buttons["flyButton"]
    XCTAssertTrue(flyButton.waitForExistence(timeout: 10), "Fly button should exist")
    flyButton.tap()
    Thread.sleep(forTimeInterval: 3.0)

    snapshot("5-fly-pre-ip")

    app.terminate()
  }

  @MainActor
  func testScreenshots_ipLate() throws {
    let app = launch()

    makeTarget(app: app)
    setTimeEntry(app: app, minutesFromNow: 3)  // Late timing

    XCUIDevice.shared.location = .init(location: LocationHelper.preIPLocation())
    let flyButton = app.buttons["flyButton"]
    XCTAssertTrue(flyButton.waitForExistence(timeout: 10), "Fly button should exist")
    flyButton.tap()
    Thread.sleep(forTimeInterval: 3.0)

    snapshot("6-fly-pre-ip-late")

    app.terminate()
  }

  @MainActor
  func testScreenshots_postIP() throws {
    let app = launch()

    makeTarget(app: app)
    setTimeEntry(app: app, minutesFromNow: 2)  // Post-IP position

    XCUIDevice.shared.location = .init(location: LocationHelper.postIPLocation())
    let flyButton = app.buttons["flyButton"]
    XCTAssertTrue(flyButton.waitForExistence(timeout: 10), "Fly button should exist")
    flyButton.tap()
    Thread.sleep(forTimeInterval: 3.0)

    snapshot("7-fly-post-ip")

    app.terminate()
  }

  @MainActor
  private func launch() -> XCUIApplication {
    let app = XCUIApplication()

    setupSnapshot(app, waitForAnimations: true)

    app.launch()

    // Handle location permission directly via springboard
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    if springboard.alerts.buttons["Allow While Using App"].waitForExistence(timeout: 5) {
      springboard.alerts.buttons["Allow While Using App"].tap()
    }

    // wait for Apple Intelligence banner to self-dismiss
    _ = app.textFields["nonexistent"].waitForExistence(timeout: 10)

    return app
  }

  private func makeTarget(app: XCUIApplication, screenshot: Bool = false) {
    XCUIDevice.shared.location = .init(location: LocationHelper.targetLocation())

    // Add target button - direct access
    app.buttons["addTargetButton"].tap()

    let targetNameField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["targetNameField"]
    )!
    clearAndTypeText(in: targetNameField, text: "Dog Bone Lake", app: app)

    // Wait a moment for keyboard to dismiss
    Thread.sleep(forTimeInterval: 0.5)

    if screenshot { snapshot("0-define-target") }

    // Tap Define IP button
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

    // Wait a moment for keyboard to dismiss
    Thread.sleep(forTimeInterval: 0.5)

    if screenshot { snapshot("1-define-ip") }

    // Navigate to Time on Target
    app.buttons["timeOnTargetButton"].tap()
  }

  private func setTimeEntry(app: XCUIApplication, minutesFromNow: Double) {
    // Wait for time entry screen to appear
    XCTAssertTrue(
      app.segmentedControls["timeDisplayModePicker"]
        .waitForExistence(timeout: 2),
      "Time mode picker should appear"
    )

    // Switch to Local Time mode
    app.segmentedControls["timeDisplayModePicker"].buttons["Target Local"].tap()

    // Calculate target time
    let now = Date()
    let targetTime = now.addingTimeInterval(minutesFromNow * 60)
    let calendar = Calendar.current
    var components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second],
      from: targetTime
    )
    components.second = 0  // Zero out seconds
    let roundedTargetTime = calendar.date(from: components) ?? targetTime

    // Format time as HH:mm:ss for entry
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    formatter.timeZone = TimeZone.current  // Use local time for tests
    let timeString = formatter.string(from: roundedTargetTime)

    // Enter time using keypad helper
    enterDigits(app: app, digits: timeString)

    Thread.sleep(forTimeInterval: 1)
  }

  // MARK: - Helper Methods

  @MainActor
  private func clearAndTypeText(in textField: XCUIElement, text: String, app _: XCUIApplication) {
    textField.tap()

    // Wait a moment for field to be focused
    Thread.sleep(forTimeInterval: 0.2)

    // Triple tap to select all
    textField.tap(withNumberOfTaps: 3, numberOfTouches: 1)

    // Small delay for selection
    Thread.sleep(forTimeInterval: 0.1)

    // Type new text (will replace selection)
    textField.typeText(text + "\n")
  }

  @MainActor
  private func enterDigits(app: XCUIApplication, digits: String) {
    // Enter digits using numeric keypad
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
