import XCTest

// swiftlint:disable prefer_nimble

struct IPSetupPage: Page {
  let app: XCUIApplication

  @MainActor var isDisplayed: Bool {
    app.buttons["timeOnTargetButton"].waitForExistence(timeout: 5)
  }

  // MARK: - Elements

  @MainActor var offsetBearingField: XCUIElement { app.textFields["offsetBearingField"] }
  @MainActor var bearingReferencePicker: XCUIElement {
    app.segmentedControls["offsetBearingReferencePicker"]
  }
  @MainActor var offsetDistanceField: XCUIElement { app.textFields["offsetDistanceField"] }
  @MainActor var offsetTimeField: XCUIElement { app.textFields["offsetTimeField"] }
  @MainActor var distanceUnitPicker: XCUIElement { app.segmentedControls["distanceUnitPicker"] }
  @MainActor var groundSpeedField: XCUIElement { app.textFields["groundSpeedField"] }
  @MainActor var speedUnitPicker: XCUIElement { app.segmentedControls["speedUnitPicker"] }
  @MainActor var targetSetupButton: XCUIElement { app.buttons["targetSetupButton"] }
  @MainActor var timeOnTargetButton: XCUIElement { app.buttons["timeOnTargetButton"] }
  @MainActor var offsetTypePicker: XCUIElement {
    app.segmentedControls["offsetTypePicker"]
  }

  // MARK: - Inbound label

  @MainActor
  func inboundLabel() -> String? {
    let predicate = NSPredicate(format: "label BEGINSWITH 'Inbound:'")
    let match = app.staticTexts.element(matching: predicate)
    if match.waitForExistence(timeout: 3) {
      return match.label
    }
    return nil
  }

  // MARK: - Actions

  @MainActor
  func enterBearing(_ value: String) {
    let field = scrollToVisible(offsetBearingField) ?? offsetBearingField
    XCTAssertTrue(field.waitForExistence(timeout: 5), "Bearing field should appear")
    clearAndType(in: field, text: value)
  }

  @MainActor
  func selectBearingReference(_ reference: String) {
    let picker = scrollToVisible(bearingReferencePicker) ?? bearingReferencePicker
    XCTAssertTrue(picker.waitForExistence(timeout: 3), "Bearing reference picker should appear")
    picker.buttons[reference].tap()
  }

  @MainActor
  func enterOffsetDistance(_ value: String) {
    let field = scrollToVisible(offsetDistanceField) ?? offsetDistanceField
    XCTAssertTrue(field.waitForExistence(timeout: 3), "Offset distance field should appear")
    clearAndType(in: field, text: value)
  }

  @MainActor
  func enterOffsetTime(_ value: String) {
    let field = scrollToVisible(offsetTimeField) ?? offsetTimeField
    XCTAssertTrue(field.waitForExistence(timeout: 3), "Offset time field should appear")
    clearAndType(in: field, text: value)
  }

  @MainActor
  func selectOffsetType(_ type: String) {
    let picker = scrollToVisible(offsetTypePicker) ?? offsetTypePicker
    XCTAssertTrue(picker.waitForExistence(timeout: 3), "Offset type picker should appear")
    picker.buttons[type].tap()
  }

  @MainActor
  func enterGroundSpeed(_ value: String) {
    let field = scrollToVisible(groundSpeedField) ?? groundSpeedField
    XCTAssertTrue(field.waitForExistence(timeout: 3), "Ground speed field should appear")
    clearAndType(in: field, text: value)
  }

  @MainActor
  @discardableResult
  func tapTimeOnTarget() -> TOTSetupPage {
    XCTAssertTrue(timeOnTargetButton.waitForExistence(timeout: 5))
    timeOnTargetButton.tap()
    return TOTSetupPage(app: app)
  }

  @MainActor
  @discardableResult
  func tapBackToTargetSetup() -> TargetSetupPage {
    targetSetupButton.tap()
    return TargetSetupPage(app: app)
  }
}

// swiftlint:enable prefer_nimble
