import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

struct TargetSetupPage: Page {
  let app: XCUIApplication

  @MainActor var isDisplayed: Bool {
    app.buttons["defineIPButton"].waitForExistence(timeout: 5)
  }

  // MARK: - Elements

  @MainActor var targetNameField: XCUIElement { app.textFields["targetNameField"] }
  @MainActor var targetCoordinates: XCUIElement { app.buttons["targetCoordinates"] }
  @MainActor var setCoordinatesButton: XCUIElement { app.buttons["setCoordinatesButton"] }
  @MainActor var findLocationButton: XCUIElement { app.buttons["findLocationButton"] }
  @MainActor var defineIPButton: XCUIElement { app.buttons["defineIPButton"] }

  // MARK: - Actions

  @MainActor
  func enterTargetName(_ name: String) {
    let field = scrollToVisible(targetNameField) ?? targetNameField
    XCTAssertTrue(field.waitForExistence(timeout: 5), "Target name field should appear")
    field.clearAndType(name, app: app)
  }

  @MainActor
  func tapCoordinatesToCycleFormat() {
    let coords = scrollToVisible(targetCoordinates) ?? targetCoordinates
    XCTAssertTrue(coords.waitForExistence(timeout: 3), "Coordinates should be displayed")
    coords.forceTap()
  }

  @MainActor
  @discardableResult
  func tapSetCoordinates() -> CoordinateEntryPage {
    let button = scrollToVisible(setCoordinatesButton) ?? setCoordinatesButton
    XCTAssertTrue(button.waitForExistence(timeout: 3), "Set Coordinates button should appear")
    button.forceTap()
    return CoordinateEntryPage(app: app)
  }

  @MainActor
  @discardableResult
  func tapFindLocation() -> FindLocationPage {
    let button = scrollToVisible(findLocationButton) ?? findLocationButton
    button.forceTap()
    return FindLocationPage(app: app)
  }

  @MainActor
  @discardableResult
  func tapDefineIP() -> IPSetupPage {
    XCTAssertTrue(defineIPButton.waitForExistence(timeout: 5), "Define IP button should appear")
    defineIPButton.forceTap()
    return IPSetupPage(app: app)
  }

  @MainActor
  @discardableResult
  func navigateBackToList() -> TargetListPage {
    tapBackButton()
    return TargetListPage(app: app)
  }

  // MARK: - Queries

  @MainActor
  func coordinatesLabel() -> String {
    let coords = scrollToVisible(targetCoordinates) ?? targetCoordinates
    XCTAssertTrue(coords.waitForExistence(timeout: 5), "Coordinates should be displayed")
    return coords.label
  }
}

// swiftlint:enable prefer_nimble
