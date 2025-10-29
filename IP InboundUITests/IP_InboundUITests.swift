import CoreLocation
import XCTest

// swiftlint:disable prefer_nimble
// swiftlint:disable empty_count

final class IP_InboundUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  // MARK: - Target Management Tests

  @MainActor
  func testCreateNewTarget() throws {
    let app = XCUIApplication()
    app.resetAuthorizationStatus(for: .location)
    app.launch()

    // Simulate location after launch
    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )

    // Handle location permission if it appears
    handleLocationPermissionIfNeeded(app: app)

    // Tap the add target button (navigation button - direct access)
    app.buttons["addTargetButton"].tap()

    // Enter target name (form field - may need scrolling)
    let targetNameField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["targetNameField"]
    )!
    clearAndTypeText(in: targetNameField, text: "Test Target Alpha", app: app)

    // Verify the target was created
    XCTAssertTrue(app.buttons["defineIPButton"].exists)

    // Clean up: Delete the created target
    deleteTargetWithName("Test Target Alpha", app: app)
  }

  @MainActor
  func testSelectExistingTarget() throws {
    let app = XCUIApplication()
    app.resetAuthorizationStatus(for: .location)
    app.launch()

    // Simulate location after launch
    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )

    handleLocationPermissionIfNeeded(app: app)

    // First create a target
    createTargetWithName("Selection Test Target", app: app)

    // After creating, we're already in the detail view
    // Verify we're in the target setup view first
    XCTAssertTrue(app.buttons["defineIPButton"].exists)

    // Go back to the list to test selection
    if !isIPad() {
      // On iPhone, go back to list
      app.navigationBars.buttons.element(boundBy: 0).tap()
      waitForNavigation()
    }

    // Find and select the target from the list
    let targetItem = findTargetListItem(withName: "Selection Test Target", app: app)
    targetItem.tap()

    // Wait for and verify we're back in the target setup view
    XCTAssertTrue(
      app.buttons["defineIPButton"].waitForExistence(timeout: 2),
      "Should navigate to target detail view"
    )

    // Clean up: Delete the created target
    deleteTargetWithName("Selection Test Target", app: app)
  }

  @MainActor
  func testAccessTutorial() throws {
    let app = XCUIApplication()
    app.resetAuthorizationStatus(for: .location)
    app.launch()

    // Simulate location after launch
    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )

    handleLocationPermissionIfNeeded(app: app)

    // Find and tap the tutorial button (navigation button - direct access)
    app.buttons["tutorialButton"].tap()

    // Verify the tutorial view appears
    // Look for some element that would be unique to the tutorial
    let tutorialView = app.otherElements["TutorialView"]
    if !tutorialView.exists {
      // Fallback: check for any text that might appear in tutorial
      let tutorialText = app.staticTexts.element(
        matching: NSPredicate(format: "label CONTAINS[c] 'tutorial'")
      )
      if !tutorialText.exists && !app.navigationBars["Tutorial"].exists {
        XCTFail("Tutorial view did not appear - no tutorial elements found")
      }
    }

    // Dismiss the tutorial - try Done first, then Close, then swipe
    if app.buttons["Done"].exists {
      app.buttons["Done"].tap()
    } else if app.buttons["Close"].exists {
      app.buttons["Close"].tap()
    } else {
      app.swipeDown()
    }
  }

  // MARK: - Coordinate Entry Tests

  @MainActor
  func testCoordinateEntry_DecimalDegrees() throws {
    let app = XCUIApplication()
    setupLocationSimulation(for: app)
    app.launch()

    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
    handleLocationPermissionIfNeeded(app: app)

    // Create a target and navigate to coordinate entry
    createTargetWithName("DD Test Target", app: app)

    // Open coordinate entry (form button - may need scrolling)
    let setCoordinatesButton = app.collectionViews.firstMatch.makeVisible(
      element: app.buttons["setCoordinatesButton"]
    )!
    setCoordinatesButton.tap()

    // Wait for coordinate format picker to appear
    let coordinateFormatPicker = app.segmentedControls["coordinateFormatPicker"]
    XCTAssertTrue(
      coordinateFormatPicker.waitForExistence(timeout: 2),
      "Coordinate format picker should appear"
    )
    coordinateFormatPicker.buttons["DD"].tap()

    app.buttons["North"].tap()
    enterDigits(app: app, digits: "37.12345")
    app.buttons["West"].tap()
    enterDigits(app: app, digits: "121.67890")

    // Accept the coordinate entry
    app.buttons["Accept"].tap()

    // Verify we're back in the target setup view
    XCTAssertTrue(app.buttons["defineIPButton"].exists)

    // Verify the coordinates were saved correctly in DD format
    let coordinatesText = app.buttons["targetCoordinates"]
    XCTAssertTrue(coordinatesText.exists, "Coordinates should be displayed")
    XCTAssertTrue(
      coordinatesText.label.contains("N 37.12345°"),
      "Latitude should be N 37.12345° but was: \(coordinatesText.label)"
    )
    XCTAssertTrue(
      coordinatesText.label.contains("W 121.67890°"),
      "Longitude should be W 121.67890° but was: \(coordinatesText.label)"
    )

    // Clean up: Delete the created target
    deleteTargetWithName("DD Test Target", app: app)
  }

  @MainActor
  func testCoordinateEntry_DegreesMinutesSeconds() throws {
    let app = XCUIApplication()
    setupLocationSimulation(for: app)
    app.launch()

    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
    handleLocationPermissionIfNeeded(app: app)

    createTargetWithName("DMS Test Target", app: app)

    // Open coordinate entry (form button - may need scrolling)
    let setCoordinatesButton = app.collectionViews.firstMatch.makeVisible(
      element: app.buttons["setCoordinatesButton"]
    )!
    setCoordinatesButton.tap()
    waitForNavigation()

    // Switch to DMS format
    let coordinateFormatPicker = app.segmentedControls["coordinateFormatPicker"]
    coordinateFormatPicker.buttons["DMS"].tap()

    app.buttons["North"].tap()
    enterDigits(app: app, digits: "37 12 34")

    app.buttons["West"].tap()
    enterDigits(app: app, digits: "121 23 45")

    // Accept the coordinate entry
    app.buttons["Accept"].tap()

    // Verify we're back in the target setup view
    XCTAssertTrue(app.buttons["defineIPButton"].exists)

    // Verify the coordinates were saved correctly in DD format
    let coordinatesText = app.buttons["targetCoordinates"]
    XCTAssertTrue(coordinatesText.exists, "Coordinates should be displayed")
    XCTAssertTrue(
      coordinatesText.label.contains("N 37° 12′ 34″"),
      "Latitude should be N 37° 12′ 34″ but was: \(coordinatesText.label)"
    )
    XCTAssertTrue(
      coordinatesText.label.contains("W 121° 23′ 45″"),
      "Longitude should be W W 121° 23′ 45″ but was: \(coordinatesText.label)"
    )

    // Clean up: Delete the created target
    deleteTargetWithName("DMS Test Target", app: app)
  }

  @MainActor
  func testCoordinateEntry_DegreesDecimalMinutes() throws {
    let app = XCUIApplication()
    setupLocationSimulation(for: app)
    app.launch()

    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
    handleLocationPermissionIfNeeded(app: app)

    createTargetWithName("DDM Test Target", app: app)

    // Open coordinate entry (form button - may need scrolling)
    let setCoordinatesButton = app.collectionViews.firstMatch.makeVisible(
      element: app.buttons["setCoordinatesButton"]
    )!
    setCoordinatesButton.tap()
    waitForNavigation()

    // Switch to DMS format
    let coordinateFormatPicker = app.segmentedControls["coordinateFormatPicker"]
    coordinateFormatPicker.buttons["DDM"].tap()

    app.buttons["North"].tap()
    enterDigits(app: app, digits: "37 12.345")

    app.buttons["West"].tap()
    enterDigits(app: app, digits: "121 23.456")

    // Accept the coordinate entry
    app.buttons["Accept"].tap()

    // Verify we're back in the target setup view
    XCTAssertTrue(app.buttons["defineIPButton"].exists)

    // Verify the coordinates were saved correctly in DD format
    let coordinatesText = app.buttons["targetCoordinates"]
    XCTAssertTrue(coordinatesText.exists, "Coordinates should be displayed")
    XCTAssertTrue(
      coordinatesText.label.contains("N 37° 12.345′"),
      "Latitude should be N 37° 12.345′ but was: \(coordinatesText.label)"
    )
    XCTAssertTrue(
      coordinatesText.label.contains("W 121° 23.456′"),
      "Longitude should be W 121° 23.456′ but was: \(coordinatesText.label)"
    )

    // Clean up: Delete the created target
    deleteTargetWithName("DDM Test Target", app: app)
  }

  // Simplified test - UTM uses different keypad
  @MainActor
  func testCoordinateEntry_UTM() throws {
    let app = XCUIApplication()
    setupLocationSimulation(for: app)
    app.launch()

    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
    handleLocationPermissionIfNeeded(app: app)

    createTargetWithName("UTM Test Target", app: app)

    // Open coordinate entry (form button - may need scrolling)
    let setCoordinatesButton = app.collectionViews.firstMatch.makeVisible(
      element: app.buttons["setCoordinatesButton"]
    )!
    setCoordinatesButton.tap()
    waitForNavigation()

    // Switch to UTM format
    let coordinateFormatPicker = app.segmentedControls["coordinateFormatPicker"]
    coordinateFormatPicker.buttons["UTM"].tap()

    enterDigits(app: app, digits: "10S 551000 418900")

    // Accept the coordinate entry
    app.buttons["Accept"].tap()

    // Verify we're back in the target setup view
    XCTAssertTrue(app.buttons["defineIPButton"].exists)

    // Verify the coordinates were saved correctly in DD format
    let coordinatesText = app.buttons["targetCoordinates"]
    XCTAssertTrue(coordinatesText.exists, "Coordinates should be displayed")
    XCTAssertTrue(
      coordinatesText.label.contains("10S"),
      "UTM should be 10S 551000 418900 but was: \(coordinatesText.label)"
    )

    // Clean up: Delete the created target
    deleteTargetWithName("UTM Test Target", app: app)
  }

  // Simplified test - MGRS uses text entry
  @MainActor
  func testCoordinateEntry_MGRS() throws {
    let app = XCUIApplication()
    setupLocationSimulation(for: app)
    app.launch()

    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
    handleLocationPermissionIfNeeded(app: app)

    createTargetWithName("MGRS Test Target", app: app)

    // Open coordinate entry (form button - may need scrolling)
    let setCoordinatesButton = app.collectionViews.firstMatch.makeVisible(
      element: app.buttons["setCoordinatesButton"]
    )!
    setCoordinatesButton.tap()
    waitForNavigation()

    // Switch to MGRS format
    let coordinateFormatPicker = app.segmentedControls["coordinateFormatPicker"]
    coordinateFormatPicker.buttons["MGRS"].tap()

    enterDigits(app: app, digits: "12U UA 84323 40791")

    app.buttons["Accept"].tap()

    // Verify we're back in the target setup view
    XCTAssertTrue(app.buttons["defineIPButton"].exists)

    // Verify the coordinates were saved correctly in DD format
    let coordinatesText = app.buttons["targetCoordinates"]
    XCTAssertTrue(coordinatesText.exists, "Coordinates should be displayed")
    XCTAssertTrue(
      coordinatesText.label.contains("12U UA 84323 40791"),
      "MGRS should be 12U UA 84323 40791 but was: \(coordinatesText.label)"
    )

    // Clean up: Delete the created target
    deleteTargetWithName("MGRS Test Target", app: app)
  }

  // MARK: - TOT Entry Tests

  @MainActor
  func testTimeEntry_Local() throws {
    let app = XCUIApplication()
    setupLocationSimulation(for: app)
    app.launch()

    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
    handleLocationPermissionIfNeeded(app: app)

    // Create a target and navigate to TOT
    createTargetWithName("Local Time Test", app: app)

    // Navigate through IP setup to TOT (navigation button - direct access)
    app.buttons["defineIPButton"].tap()

    // Wait for IP setup fields to appear
    let offsetBearingField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetBearingField"]
    )!
    XCTAssertTrue(
      offsetBearingField.waitForExistence(timeout: 2),
      "Offset bearing field should appear"
    )
    clearAndTypeText(in: offsetBearingField, text: "090", app: app)

    let offsetDistanceField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetDistanceField"]
    )!
    clearAndTypeText(in: offsetDistanceField, text: "5", app: app)

    // Time on Target button (navigation button - direct access)
    app.buttons["timeOnTargetButton"].tap()

    // Wait for time entry screen to appear
    XCTAssertTrue(
      app
        .segmentedControls["timeDisplayModePicker"]
        .waitForExistence(timeout: 2),
      "Time mode buttons should appear"
    )

    app.segmentedControls["timeDisplayModePicker"].buttons["Target Local"].tap()
    enterDigits(app: app, digits: "12:34:56")

    // Navigate back to target list to verify time is displayed
    if !isIPad() {
      // On iPhone, go back through navigation
      app.navigationBars.buttons.element(boundBy: 0).tap()  // Back to IP setup
      waitForNavigation()
      app.navigationBars.buttons.element(boundBy: 0).tap()  // Back to target setup
      waitForNavigation()
      app.navigationBars.buttons.element(boundBy: 0).tap()  // Back to target list
      waitForNavigation()
    }

    // Find the target in the list and verify the time is displayed
    var targetCell: XCUIElement?
    for i in 0..<app.cells.count {
      let cell = app.cells.element(boundBy: i)
      if cell.staticTexts.matching(
        NSPredicate(format: "identifier == 'targetListItem' AND label == %@", "Local Time Test")
      ).count > 0 {
        targetCell = cell
        break
      }
    }
    XCTAssertNotNil(targetCell, "Target cell should exist in list")
    guard let targetCell else { return }

    // Look for the time text within the cell
    let timePredicate = NSPredicate(format: "label == %@", "12:34 PM")
    let timeText = targetCell.staticTexts.element(matching: timePredicate)
    // Check for both 12-hour and 24-hour time formats
    let time24HourPredicate = NSPredicate(format: "label == %@", "12:34")
    let time24HourText = targetCell.staticTexts.element(matching: time24HourPredicate)
    XCTAssertTrue(
      timeText.exists || time24HourText.exists,
      "Time should be displayed as either '12:34 PM' (12-hour) or '12:34' (24-hour)"
    )

    // Clean up: Delete the created target
    deleteTargetFromList("Local Time Test", app: app)
  }

  @MainActor
  func testTimeEntry_Zulu() throws {
    let app = XCUIApplication()
    setupLocationSimulation(for: app)
    app.launch()

    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
    handleLocationPermissionIfNeeded(app: app)

    // Create a target and navigate to TOT
    createTargetWithName("Zulu Time Test", app: app)

    // Navigate through IP setup to TOT (navigation button - direct access)
    app.buttons["defineIPButton"].tap()

    // Wait for IP setup fields to appear
    let offsetBearingField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetBearingField"]
    )!
    XCTAssertTrue(
      offsetBearingField.waitForExistence(timeout: 2),
      "Offset bearing field should appear"
    )
    clearAndTypeText(in: offsetBearingField, text: "090", app: app)

    let offsetDistanceField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetDistanceField"]
    )!
    clearAndTypeText(in: offsetDistanceField, text: "5", app: app)

    // Time on Target button (navigation button - direct access)
    app.buttons["timeOnTargetButton"].tap()

    // Wait for time entry screen to appear
    XCTAssertTrue(
      app
        .segmentedControls["timeDisplayModePicker"]
        .waitForExistence(timeout: 2),
      "Time mode buttons should appear"
    )

    app.segmentedControls["timeDisplayModePicker"].buttons["Zulu"].tap()
    enterDigits(app: app, digits: "18:00:00")

    // Navigate back to target list to verify time is displayed
    if !isIPad() {
      // On iPhone, go back through navigation
      app.navigationBars.buttons.element(boundBy: 0).tap()  // Back to IP setup
      waitForNavigation()
      app.navigationBars.buttons.element(boundBy: 0).tap()  // Back to target setup
      waitForNavigation()
      app.navigationBars.buttons.element(boundBy: 0).tap()  // Back to target list
      waitForNavigation()
    }

    // Find the target in the list and verify the time is displayed
    var targetCell: XCUIElement?
    for i in 0..<app.cells.count {
      let cell = app.cells.element(boundBy: i)
      if cell.staticTexts.matching(
        NSPredicate(format: "identifier == 'targetListItem' AND label == %@", "Zulu Time Test")
      ).count > 0 {
        targetCell = cell
        break
      }
    }
    XCTAssertNotNil(targetCell, "Target cell should exist in list")
    guard let targetCell else { return }

    // Look for the time text within the cell
    let timePredicate = NSPredicate(format: "label == %@", "1800Z")
    let timeText = targetCell.staticTexts.element(matching: timePredicate)
    XCTAssertTrue(timeText.exists, "Time should be displayed as '1800Z'")

    // Clean up: Delete the created target
    deleteTargetFromList("Zulu Time Test", app: app)
  }

  // MARK: - Navigation Flow Tests

  @MainActor
  func testNavigationBetweenSetupSteps() throws {
    let app = XCUIApplication()
    app.resetAuthorizationStatus(for: .location)
    app.launch()

    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
    handleLocationPermissionIfNeeded(app: app)

    // Create a target
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

    // Navigate back through the flow
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

    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: 37.7749, longitude: -122.4194)
    )
    handleLocationPermissionIfNeeded(app: app)

    // Create and configure a target
    createAndConfigureTarget(app: app)

    // Navigate back to the target list (need to go back 3 levels from Time on Target)
    if !isIPad() {
      // Back from Time on Target to IP Setup
      app.navigationBars.buttons.element(boundBy: 0).tap()
      waitForNavigation()
      // Back from IP Setup to Target Setup
      app.navigationBars.buttons.element(boundBy: 0).tap()
      waitForNavigation()
      // Back from Target Setup to Target List
      app.navigationBars.buttons.element(boundBy: 0).tap()
      waitForNavigation()
    }

    // Find and select the target from the list
    let targetItem = findTargetListItem(withName: "Quick Target", app: app)
    targetItem.tap()

    // Verify we're back in the target setup view
    XCTAssertTrue(
      app.buttons["defineIPButton"].waitForExistence(timeout: 10),
      "Should navigate to target detail view"
    )

    // Clean up
    deleteTargetWithName("Quick Target", app: app)
  }

  // MARK: - Helper Methods

  @MainActor
  private func setupLocationSimulation(for app: XCUIApplication) {
    app.resetAuthorizationStatus(for: .location)
  }

  @MainActor
  private func handleLocationPermissionIfNeeded(app _: XCUIApplication) {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let allowButton = springboard.alerts.buttons["Allow While Using App"]
    if allowButton.waitForExistence(timeout: 2) {
      allowButton.tap()
    }
  }

  @MainActor
  private func createTargetWithName(_ name: String, app: XCUIApplication) {
    // Add target button is a navigation button - direct access
    app.buttons["addTargetButton"].tap()

    // Wait for target name field to appear instead of generic navigation wait
    let targetNameField = app.textFields["targetNameField"]
    XCTAssertTrue(targetNameField.waitForExistence(timeout: 2), "Target name field should appear")
    clearAndTypeText(in: targetNameField, text: name, app: app)
  }

  @MainActor
  private func findTargetListItem(withName name: String? = nil, app: XCUIApplication) -> XCUIElement
  {
    // Try multiple strategies to find the list item

    // First try to find the cell containing the target name
    if let name {
      // Find the static text with the target name
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
  private func isIPad() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
  }

  @MainActor
  private func deleteTargetWithName(_ name: String, app: XCUIApplication) {
    // Navigate back to list if needed
    if !isIPad() {
      // On iPhone, go back to list
      app.navigationBars.buttons.element(boundBy: 0).tap()
      waitForNavigation()
    } else {
      // On iPad, the list should be visible in split view
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

  // MARK: - Keypad Helper Methods

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
