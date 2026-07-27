import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

struct IPSetupPage: Page {
  let app: XCUIApplication

  var isDisplayed: Bool {
    app.buttons["timeOnTargetButton"].waitForExistence(timeout: 5)
  }

  // MARK: - Elements

  var offsetBearingField: XCUIElement { app.textFields["offsetBearingField"] }
  var bearingReferencePicker: XCUIElement {
    app.segmentedControls["offsetBearingReferencePicker"]
  }
  var offsetDistanceField: XCUIElement { app.textFields["offsetDistanceField"] }
  var offsetTimeField: XCUIElement { app.textFields["offsetTimeField"] }
  var distanceUnitPicker: XCUIElement { app.segmentedControls["distanceUnitPicker"] }
  var groundSpeedField: XCUIElement { app.textFields["groundSpeedField"] }
  var speedUnitPicker: XCUIElement { app.segmentedControls["speedUnitPicker"] }
  var targetSetupButton: XCUIElement { app.buttons["targetSetupButton"] }
  var timeOnTargetButton: XCUIElement { app.buttons["timeOnTargetButton"] }
  var offsetTypePicker: XCUIElement {
    app.segmentedControls["offsetTypePicker"]
  }

  // MARK: - Inbound label

  func inboundLabel() -> String? {
    let predicate = NSPredicate(format: "label BEGINSWITH 'Inbound:'")
    let match = app.staticTexts.element(matching: predicate)
    if match.waitForExistence(timeout: 3) {
      return match.label
    }
    return nil
  }

  // MARK: - Actions

  func enterBearing(_ value: String) {
    let field = scrollToVisible(offsetBearingField) ?? offsetBearingField
    XCTAssertTrue(field.waitForExistence(timeout: 5), "Bearing field should appear")
    field.clearAndType(value, app: app)
  }

  func selectBearingReference(_ reference: String) {
    let picker = scrollToVisible(bearingReferencePicker) ?? bearingReferencePicker
    XCTAssertTrue(picker.waitForExistence(timeout: 3), "Bearing reference picker should appear")
    picker.buttons[reference].forceTap()
  }

  func enterOffsetDistance(_ value: String) {
    let field = scrollToVisible(offsetDistanceField) ?? offsetDistanceField
    XCTAssertTrue(field.waitForExistence(timeout: 3), "Offset distance field should appear")
    field.clearAndType(value, app: app)
  }

  /// Commit a pending offset-distance edit by moving focus to another field.
  /// numberPad keyboards have no Return key, and on the iPad the form fits
  /// without scrolling, so the keyboard can't be dismissed by tapping a blank
  /// area or swiping — only a focus change ends editing and writes the
  /// `TextField(value:format:)` binding.
  func commitOffsetDistance() {
    let target = scrollToVisible(offsetBearingField) ?? offsetBearingField
    offsetDistanceField.commitByMovingFocus(to: target)
  }

  func enterOffsetTime(_ value: String) {
    let field = scrollToVisible(offsetTimeField) ?? offsetTimeField
    XCTAssertTrue(field.waitForExistence(timeout: 3), "Offset time field should appear")
    field.clearAndType(value, app: app)
  }

  func selectOffsetType(_ type: String) {
    let picker = scrollToVisible(offsetTypePicker) ?? offsetTypePicker
    XCTAssertTrue(picker.waitForExistence(timeout: 3), "Offset type picker should appear")
    picker.buttons[type].forceTap()
  }

  func enterGroundSpeed(_ value: String) {
    let field = scrollToVisible(groundSpeedField) ?? groundSpeedField
    XCTAssertTrue(field.waitForExistence(timeout: 3), "Ground speed field should appear")
    field.clearAndType(value, app: app)
  }

  @discardableResult
  func tapTimeOnTarget() -> TOTSetupPage {
    tapButton("timeOnTargetButton", toReveal: app.segmentedControls["timeDisplayModePicker"])
    return TOTSetupPage(app: app)
  }

  @discardableResult
  func tapBackToTargetSetup() -> TargetSetupPage {
    tapButton("targetSetupButton", toReveal: app.textFields["targetNameField"])
    return TargetSetupPage(app: app)
  }
}

// swiftlint:enable prefer_nimble
