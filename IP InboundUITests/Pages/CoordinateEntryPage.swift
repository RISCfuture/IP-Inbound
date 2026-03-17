import XCTest

// swiftlint:disable prefer_nimble

struct CoordinateEntryPage: Page {
  let app: XCUIApplication

  @MainActor var isDisplayed: Bool {
    app.segmentedControls["coordinateFormatPicker"].waitForExistence(timeout: 3)
  }

  // MARK: - Elements

  @MainActor var formatPicker: XCUIElement { app.segmentedControls["coordinateFormatPicker"] }
  @MainActor var acceptButton: XCUIElement { app.buttons["Accept"] }
  @MainActor var cancelButton: XCUIElement { app.buttons["Cancel"] }

  // MARK: - Actions

  @MainActor
  func selectFormat(_ format: String) {
    XCTAssertTrue(formatPicker.waitForExistence(timeout: 3), "Format picker should appear")
    formatPicker.buttons[format].tap()
  }

  @MainActor
  func enterLatLon(
    lat: (direction: String, digits: String),
    lon: (direction: String, digits: String)
  ) {
    tapDirection(lat.direction)
    enterOnKeypad(lat.digits)
    tapDirection(lon.direction)
    enterOnKeypad(lon.digits)
  }

  @MainActor
  func enterGridCoordinate(_ grid: String) {
    // Wait for keypad to be ready
    let firstButton = app.buttons["keypad-1"]
    XCTAssertTrue(firstButton.waitForExistence(timeout: 3), "Grid keypad should appear")
    waitForHittable(firstButton)
    enterOnKeypad(grid)
  }

  @MainActor
  @discardableResult
  func tapAccept() -> TargetSetupPage {
    XCTAssertTrue(acceptButton.waitForExistence(timeout: 3), "Accept button should exist")
    // Wait for Accept to be enabled
    let enabledPredicate = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "isEnabled == true"),
      object: acceptButton
    )
    _ = XCTWaiter.wait(for: [enabledPredicate], timeout: 3)
    acceptButton.tap()
    return TargetSetupPage(app: app)
  }

  @MainActor
  @discardableResult
  func tapCancel() -> TargetSetupPage {
    cancelButton.tap()
    return TargetSetupPage(app: app)
  }
}

// swiftlint:enable prefer_nimble
