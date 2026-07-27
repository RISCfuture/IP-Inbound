import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

struct TargetSetupPage: Page {
  let app: XCUIApplication

  var isDisplayed: Bool {
    app.buttons["defineIPButton"].waitForExistence(timeout: 5)
  }

  // MARK: - Elements

  var targetNameField: XCUIElement { app.textFields["targetNameField"] }
  var targetCoordinates: XCUIElement { app.buttons["targetCoordinates"] }
  var setCoordinatesButton: XCUIElement { app.buttons["setCoordinatesButton"] }
  var findLocationButton: XCUIElement { app.buttons["findLocationButton"] }
  var defineIPButton: XCUIElement { app.buttons["defineIPButton"] }

  // MARK: - Actions

  func enterTargetName(_ name: String) {
    let field = scrollToVisible(targetNameField) ?? targetNameField
    XCTAssertTrue(field.waitForExistence(timeout: 5), "Target name field should appear")
    field.clearAndType(name, app: app)
  }

  func tapCoordinatesToCycleFormat() {
    let coords = scrollToVisible(targetCoordinates) ?? targetCoordinates
    XCTAssertTrue(coords.waitForExistence(timeout: 3), "Coordinates should be displayed")
    coords.forceTap()
  }

  @discardableResult
  func tapSetCoordinates() -> CoordinateEntryPage {
    let button = scrollToVisible(setCoordinatesButton) ?? setCoordinatesButton
    XCTAssertTrue(button.waitForExistence(timeout: 3), "Set Coordinates button should appear")
    button.forceTap()
    return CoordinateEntryPage(app: app)
  }

  @discardableResult
  func tapFindLocation() -> FindLocationPage {
    let button = scrollToVisible(findLocationButton) ?? findLocationButton
    button.forceTap()
    return FindLocationPage(app: app)
  }

  @discardableResult
  func tapDefineIP() -> IPSetupPage {
    XCTAssertTrue(defineIPButton.waitForExistence(timeout: 5), "Define IP button should appear")
    defineIPButton.forceTap()
    return IPSetupPage(app: app)
  }

  @discardableResult
  func navigateBackToList() -> TargetListPage {
    tapBackButton()
    return TargetListPage(app: app)
  }

  /// Advance an already-configured target through any residual setup pages to
  /// the Fly view. Selecting a configured target usually lands directly on Fly,
  /// but SwiftUI sometimes restores the Define Target / IP / TOT pages across
  /// selection even with `isConfigured == true`; this walks whichever forward
  /// links are present (each guarded by an existence wait, never a fixed sleep).
  @discardableResult
  func advanceThroughSetupToFly() -> FlyPage {
    if defineIPButton.waitForExistence(timeout: 2) {
      defineIPButton.tap()
    }
    if app.buttons["timeOnTargetButton"].waitForExistence(timeout: 2) {
      app.buttons["timeOnTargetButton"].tap()
    }
    if app.buttons["flyButton"].waitForExistence(timeout: 2) {
      app.buttons["flyButton"].tap()
    }
    return FlyPage(app: app)
  }

  // MARK: - Queries

  func coordinatesLabel() -> String {
    let coords = scrollToVisible(targetCoordinates) ?? targetCoordinates
    XCTAssertTrue(coords.waitForExistence(timeout: 5), "Coordinates should be displayed")
    return coords.label
  }
}

// swiftlint:enable prefer_nimble
