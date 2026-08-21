import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

struct CoordinateEntryPage: Page {
  let app: XCUIApplication

  var isDisplayed: Bool {
    app.segmentedControls["coordinateFormatPicker"].waitForExistence(timeout: 3)
  }

  // MARK: - Elements

  var formatPicker: XCUIElement { app.segmentedControls["coordinateFormatPicker"] }
  var acceptButton: XCUIElement { app.buttons["Accept"] }
  var cancelButton: XCUIElement { app.buttons["Cancel"] }

  // MARK: - Actions

  func selectFormat(_ format: String) {
    XCTAssertTrue(formatPicker.waitForExistence(timeout: 3), "Format picker should appear")
    formatPicker.buttons[format].forceTap()
  }

  func enterLatLon(
    lat: (direction: String, digits: String),
    lon: (direction: String, digits: String)
  ) async {
    await tapDirection(lat.direction)
    enterOnKeypad(lat.digits)
    await tapDirection(lon.direction)
    enterOnKeypad(lon.digits)
  }

  func enterGridCoordinate(_ grid: String) {
    // Wait for keypad to be ready (longer timeout for CI where format switch is slow)
    let firstButton = app.buttons["keypad-1"]
    XCTAssertTrue(firstButton.waitForExistence(timeout: 10), "Grid keypad should appear")
    firstButton.waitUntilHittable(timeout: 10)
    enterOnKeypad(grid)
  }

  @discardableResult
  func tapAccept() -> TargetSetupPage {
    XCTAssertTrue(acceptButton.waitForExistence(timeout: 3), "Accept button should exist")
    // Wait for Accept to be enabled
    let enabledPredicate = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "isEnabled == true"),
      object: acceptButton
    )
    _ = XCTWaiter.wait(for: [enabledPredicate], timeout: 3)
    acceptButton.forceTap()
    return TargetSetupPage(app: app)
  }

  @discardableResult
  func tapCancel() -> TargetSetupPage {
    cancelButton.forceTap()
    return TargetSetupPage(app: app)
  }
}

// swiftlint:enable prefer_nimble
