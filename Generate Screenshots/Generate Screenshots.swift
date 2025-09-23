// swiftlint:disable prefer_nimble

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
    app.buttons["flyButton"].tap()
    XCTAssert(app.staticTexts["countdown"].waitForExistence(timeout: 60))

    snapshot("3-fly-ground")

    app.terminate()
  }

  @MainActor
  func testScreenshots_ipEarly() throws {
    let app = launch()

    makeTarget(app: app)
    setTimeEntry(app: app, minutesFromNow: 15)  // Early - shows route via IP with time to spare

    XCUIDevice.shared.location = .init(location: LocationHelper.preIPLocation())
    app.buttons["flyButton"].tap()
    XCTAssert(app.staticTexts["cdi"].waitForExistence(timeout: 60))

    snapshot("4-fly-pre-ip-early")

    app.terminate()
  }

  @MainActor
  func testScreenshots_ip() throws {
    let app = launch()

    makeTarget(app: app)
    setTimeEntry(app: app, minutesFromNow: 6)  // On-time - should show route via IP with speed guidance

    XCUIDevice.shared.location = .init(location: LocationHelper.preIPLocation())
    app.buttons["flyButton"].tap()
    XCTAssert(app.staticTexts["cdi"].waitForExistence(timeout: 60))

    snapshot("5-fly-pre-ip")

    app.terminate()
  }

  @MainActor
  func testScreenshots_ipLate() throws {
    let app = launch()

    makeTarget(app: app)
    setTimeEntry(app: app, minutesFromNow: 3)  // Late timing

    XCUIDevice.shared.location = .init(location: LocationHelper.preIPLocation())
    app.buttons["flyButton"].tap()
    XCTAssert(app.staticTexts["cdi"].waitForExistence(timeout: 60))

    snapshot("6-fly-pre-ip-late")

    app.terminate()
  }

  @MainActor
  func testScreenshots_postIP() throws {
    let app = launch()

    makeTarget(app: app)
    setTimeEntry(app: app, minutesFromNow: 2)  // Post-IP position

    XCUIDevice.shared.location = .init(location: LocationHelper.postIPLocation())
    app.buttons["flyButton"].tap()
    XCTAssert(app.staticTexts["cdi"].waitForExistence(timeout: 60))

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

    // wait 20 seconds for Apple Intelligence banner to self-dismiss
    _ = app.textFields["nonexistent"].waitForExistence(timeout: 20)

    return app
  }

  private func makeTarget(app: XCUIApplication, screenshot: Bool = false) {
    XCUIDevice.shared.location = .init(location: LocationHelper.targetLocation())

    if app.buttons["ToggleSidebar"].waitForExistence(timeout: 1) {
      app.buttons["ToggleSidebar"].tap()
    }

    app.buttons["addTargetButton"].firstMatch.tap()
    XCTAssert(app.textFields["targetNameField"].waitForExistence(timeout: 60))

    app.textFields["targetNameField"].tap()
    app.textFields["targetNameField"].tap(withNumberOfTaps: 3, numberOfTouches: 1)
    app.textFields["targetNameField"].typeText("Dog Bone Lake\n")
    sleep(5)

    if screenshot {
      snapshot("0-define-target")
    }

    app.buttons["defineIPButton"].tap()
    XCTAssert(app.textFields["offsetBearingField"].waitForExistence(timeout: 60))

    app.textFields["offsetBearingField"].doubleTap()
    app.textFields["offsetBearingField"].typeText("\(Int(LocationHelper.IPBearingTrue))")
    app.buttons["offsetBearingTrue"].tap()

    app.textFields["offsetDistanceField"].doubleTap()
    app.textFields["offsetDistanceField"].typeText("\(LocationHelper.IPDistanceNM)")

    app.textFields["targetGroundSpeedField"].doubleTap()
    app.textFields["targetGroundSpeedField"].typeText("\(LocationHelper.targetGroundSpeed)\n")

    if screenshot {
      snapshot("1-define-ip")
    }

    app.buttons["timeOnTargetButton"].tap()
  }

  private func setTimeEntry(app: XCUIApplication, minutesFromNow: Double) {
    XCTAssert(app.otherElements["totEntryView"].waitForExistence(timeout: 60))
    XCTAssert(app.otherElements["timeEntryField"].waitForExistence(timeout: 5))

    // Calculate target time
    let now = Date()
    let targetTime = now.addingTimeInterval(minutesFromNow * 60)
    let calendar = Calendar.current
    var components = calendar.dateComponents(
      [.year, .month, .day, .hour, .minute, .second], from: targetTime)
    components.second = 0  // Zero out seconds
    let roundedTargetTime = calendar.date(from: components) ?? targetTime

    // Format time as HHMMSS for entry
    let formatter = DateFormatter()
    formatter.dateFormat = "HHmmss"
    formatter.timeZone = TimeZone.current  // Use local time for tests
    let timeString = formatter.string(from: roundedTargetTime)

    // Enter time digits
    for char in timeString {
      if let button = app.buttons[String(char)].firstMatch as XCUIElement?,
        button.waitForExistence(timeout: 1)
      {
        button.tap()
      }
    }

    sleep(1)
  }
}

// swiftlint:enable prefer_nimble
