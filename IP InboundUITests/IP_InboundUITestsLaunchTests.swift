import CoreLocation
import XCTest

// swiftlint:disable prefer_nimble
// swiftlint:disable empty_count

final class IP_InboundUITestsLaunchTests: XCTestCase {
  override static var runsForEachTargetApplicationUIConfiguration: Bool {
    false  // Only run once, not for each configuration
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  // MARK: - Navigation Flow Tests

  @MainActor
  func testCompleteSetupFlow() throws {
    let app = XCUIApplication()
    app.resetAuthorizationStatus(for: .location)
    app.launch()

    // Simulate location after launch
    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )

    handleLocationPermissionIfNeeded(app: app)

    // Step 1: Create a new target using the same pattern as working tests
    app.buttons["addTargetButton"].tap()

    // Enter target name using makeVisible pattern from working tests
    let targetNameField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["targetNameField"]
    )!
    clearAndTypeText(in: targetNameField, text: "Mission Target", app: app)

    // Step 2: Navigate to IP Setup
    XCTAssertTrue(app.buttons["defineIPButton"].exists)
    app.buttons["defineIPButton"].tap()

    // Step 3: Configure IP offset using makeVisible pattern
    let offsetBearingField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetBearingField"]
    )!
    XCTAssertTrue(
      offsetBearingField.waitForExistence(timeout: 2),
      "Offset bearing field should exist"
    )
    clearAndTypeText(in: offsetBearingField, text: "270", app: app)

    // Test offset distance entry using makeVisible pattern
    let offsetDistanceField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetDistanceField"]
    )!
    clearAndTypeText(in: offsetDistanceField, text: "10", app: app)

    // Step 4: Navigate to Time on Target
    app.buttons["timeOnTargetButton"].tap()

    // Wait for time entry screen to appear
    XCTAssertTrue(
      app.segmentedControls["timeDisplayModePicker"]
        .waitForExistence(timeout: 2),
      "Time mode picker should appear"
    )

    // Enter time using keypad pattern from working tests
    app.segmentedControls["timeDisplayModePicker"].buttons["Zulu"].tap()
    enterDigits(app: app, digits: "12:00:00")

    // Step 5: Navigate back and verify
    if !isIPad() {
      // On iPhone, go back through navigation
      app.navigationBars.buttons.element(boundBy: 0).tap()  // Back to IP setup
      waitForNavigation()
      app.navigationBars.buttons.element(boundBy: 0).tap()  // Back to target setup
      waitForNavigation()
      app.navigationBars.buttons.element(boundBy: 0).tap()  // Back to target list
      waitForNavigation()
    }

    // Clean up
    deleteTargetFromList("Mission Target", app: app)
  }

  @MainActor
  func testNavigationBetweenSetupSteps() throws {
    let app = XCUIApplication()
    app.resetAuthorizationStatus(for: .location)
    app.launch()

    // Simulate location after launch
    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )

    handleLocationPermissionIfNeeded(app: app)

    // Create a target using working pattern
    createTargetWithName("Nav Test Target", app: app)

    // Navigate to IP Setup
    app.buttons["defineIPButton"].tap()

    // Fill in IP setup fields
    let offsetBearingField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetBearingField"]
    )!
    XCTAssertTrue(offsetBearingField.waitForExistence(timeout: 2))
    clearAndTypeText(in: offsetBearingField, text: "090", app: app)

    let offsetDistanceField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetDistanceField"]
    )!
    clearAndTypeText(in: offsetDistanceField, text: "5", app: app)

    // Navigate to Time on Target
    app.buttons["timeOnTargetButton"].tap()

    // Verify time entry screen appears
    XCTAssertTrue(
      app.segmentedControls["timeDisplayModePicker"]
        .waitForExistence(timeout: 2),
      "Time mode picker should appear"
    )

    // Navigate back using navigation bar pattern from working tests
    if !isIPad() {
      app.navigationBars.buttons.element(boundBy: 0).tap()  // Back to IP setup
      waitForNavigation()
      XCTAssertTrue(app.buttons["timeOnTargetButton"].exists)

      app.navigationBars.buttons.element(boundBy: 0).tap()  // Back to target setup
      waitForNavigation()
      XCTAssertTrue(app.buttons["defineIPButton"].exists)
    }

    // Clean up
    deleteTargetWithName("Nav Test Target", app: app)
  }

  @MainActor
  func testDirectToFlyForConfiguredTarget() throws {
    let app = XCUIApplication()
    app.resetAuthorizationStatus(for: .location)
    app.launch()

    // Simulate location after launch
    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )

    handleLocationPermissionIfNeeded(app: app)

    // First, create and fully configure a target
    createAndConfigureTarget(app: app)

    // Navigate back to the target list
    if !isIPad() {
      // On iPhone, go back to list
      app.navigationBars.buttons.element(boundBy: 0).tap()
      waitForNavigation()
    }

    // Find and select the target from the list
    let targetItem = findTargetListItem(withName: "Quick Target", app: app)
    targetItem.tap()

    // Wait for and verify we're back in the target setup view
    XCTAssertTrue(
      app.buttons["defineIPButton"].waitForExistence(timeout: 10),
      "Should navigate to target detail view"
    )

    // Clean up
    deleteTargetWithName("Quick Target", app: app)
  }

  // MARK: - Helper Methods

  @MainActor
  private func handleLocationPermissionIfNeeded(app _: XCUIApplication) {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let allowButton = springboard.alerts.buttons["Allow While Using App"]
    if allowButton.waitForExistence(timeout: 2) {
      allowButton.tap()
    }
  }

  @MainActor
  private func waitForNavigation() {
    // Give time for navigation animation
    Thread.sleep(forTimeInterval: 0.5)
  }

  @MainActor
  private func clearAndTypeText(in textField: XCUIElement, text: String, app _: XCUIApplication) {
    textField.tap()

    // Wait a moment for field to be focused
    Thread.sleep(forTimeInterval: 0.2)

    // Always select all and replace - SwiftUI text fields may have placeholder text
    // that doesn't show up in .value property
    // Triple tap to select all
    textField.tap(withNumberOfTaps: 3, numberOfTouches: 1)

    // Small delay for selection
    Thread.sleep(forTimeInterval: 0.1)

    // Type new text (will replace selection)
    textField.typeText(text)
  }

  @MainActor
  private func createTargetWithName(_ name: String, app: XCUIApplication) {
    // Add target button is a navigation button - direct access
    app.buttons["addTargetButton"].tap()

    // Wait for target name field to appear
    let targetNameField = app.textFields["targetNameField"]
    XCTAssertTrue(targetNameField.waitForExistence(timeout: 2), "Target name field should appear")
    clearAndTypeText(in: targetNameField, text: name, app: app)
  }

  @MainActor
  private func findTargetListItem(withName name: String? = nil, app: XCUIApplication) -> XCUIElement
  {
    // Find the cell containing the target name
    if let name {
      let targetNamePredicate = NSPredicate(
        format: "identifier == 'targetListItem' AND label == %@",
        name
      )
      for i in 0..<app.cells.count {
        let cell = app.cells.element(boundBy: i)
        if cell.staticTexts.matching(targetNamePredicate).count > 0 {
          return cell
        }
      }
    }

    // Try otherElements with the identifier
    let otherElement = app.otherElements["targetListItem"].firstMatch
    if otherElement.exists {
      return otherElement
    }

    // Fallback to first cell
    return app.cells.firstMatch
  }

  @MainActor
  private func deleteTargetWithName(_ name: String, app: XCUIApplication) {
    // Navigate back to list if needed
    if !isIPad() {
      // On iPhone, go back to list
      app.navigationBars.buttons.element(boundBy: 0).tap()
      waitForNavigation()
    }

    // Find all cells and check which one contains our target name
    let cells = app.cells
    var targetCell: XCUIElement?

    for i in 0..<cells.count {
      let cell = cells.element(boundBy: i)
      if cell.staticTexts.matching(
        NSPredicate(format: "identifier == 'targetListItem' AND label == %@", name)
      ).count > 0 {
        targetCell = cell
        break
      }
    }

    XCTAssertNotNil(targetCell, "Cell containing target '\(name)' must exist")
    guard let targetCell else { return }

    // Swipe left on the target cell
    targetCell.swipeLeft()

    // Wait for delete button to appear
    let deleteButton = app.buttons["Delete"]
    XCTAssertTrue(
      deleteButton.waitForExistence(timeout: 2),
      "Delete button must appear after swipe"
    )

    // Tap the delete button
    deleteButton.tap()

    // Wait for deletion animation to complete
    Thread.sleep(forTimeInterval: 1.0)

    // Verify the target was deleted
    let targetNamePredicate = NSPredicate(
      format: "identifier == 'targetListItem' AND label == %@",
      name
    )
    let remainingTargets = app.staticTexts.matching(targetNamePredicate)
    XCTAssertEqual(
      remainingTargets.count,
      0,
      "Target '\(name)' should no longer exist after deletion"
    )

    Thread.sleep(forTimeInterval: 1.0)  // allow sync to happen
  }

  @MainActor
  private func deleteTargetFromList(_ name: String, app: XCUIApplication) {
    // This version assumes we're already in the list view
    // Find all cells and check which one contains our target name
    let cells = app.cells
    var targetCell: XCUIElement?

    for i in 0..<cells.count {
      let cell = cells.element(boundBy: i)
      if cell.staticTexts.matching(
        NSPredicate(format: "identifier == 'targetListItem' AND label == %@", name)
      ).count > 0 {
        targetCell = cell
        break
      }
    }

    XCTAssertNotNil(targetCell, "Cell containing target '\(name)' must exist")
    guard let targetCell else { return }

    // Swipe left on the target cell
    targetCell.swipeLeft()

    // Wait for delete button to appear
    let deleteButton = app.buttons["Delete"]
    XCTAssertTrue(
      deleteButton.waitForExistence(timeout: 2),
      "Delete button must appear after swipe"
    )

    // Tap the delete button
    deleteButton.tap()

    // Wait for deletion animation to complete
    Thread.sleep(forTimeInterval: 1.0)

    // Verify the target was deleted
    let targetNamePredicate = NSPredicate(
      format: "identifier == 'targetListItem' AND label == %@",
      name
    )
    let remainingTargets = app.staticTexts.matching(targetNamePredicate)
    XCTAssertEqual(
      remainingTargets.count,
      0,
      "Target '\(name)' should no longer exist after deletion"
    )

    Thread.sleep(forTimeInterval: 1.0)  // allow sync to happen
  }

  @MainActor
  private func isIPad() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
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

  @MainActor
  private func createQuickTarget(app: XCUIApplication) {
    createTargetWithName("Quick Target", app: app)
  }

  @MainActor
  private func createAndConfigureTarget(app: XCUIApplication) {
    // Create target
    createTargetWithName("Quick Target", app: app)

    // Configure IP
    app.buttons["defineIPButton"].tap()

    // Set offset values using makeVisible pattern
    let offsetBearingField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetBearingField"]
    )!
    XCTAssertTrue(offsetBearingField.waitForExistence(timeout: 2))
    clearAndTypeText(in: offsetBearingField, text: "090", app: app)

    let offsetDistanceField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetDistanceField"]
    )!
    clearAndTypeText(in: offsetDistanceField, text: "5", app: app)

    // Go to Time on Target
    app.buttons["timeOnTargetButton"].tap()

    // Wait for time entry screen
    XCTAssertTrue(
      app.segmentedControls["timeDisplayModePicker"]
        .waitForExistence(timeout: 2),
      "Time mode picker should appear"
    )

    // Enter a time using the keypad
    app.segmentedControls["timeDisplayModePicker"].buttons["Zulu"].tap()
    enterDigits(app: app, digits: "12:00:00")
  }
}

// swiftlint:enable prefer_nimble
// swiftlint:enable empty_count
