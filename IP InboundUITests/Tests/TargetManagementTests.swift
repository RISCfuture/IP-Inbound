import XCTest

// swiftlint:disable prefer_nimble

final class TargetManagementTests: BaseTestCase {

  // MARK: - Test 1

  @MainActor
  func testCreateNewTarget() throws {
    try skipOniOS18()
    launchApp()
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "Alpha")
    XCTAssertTrue(setup.isDisplayed, "Should be on target setup view")

    // Navigate back and verify target appears in list
    let listPage: TargetListPage
    if !isIPad {
      listPage = setup.navigateBackToList()
    } else {
      listPage = list
    }
    let cell = listPage.targetCell(named: "Alpha")
    XCTAssertNotNil(cell, "Cell with text 'Alpha' should appear in list")

    // Clean up
    listPage.deleteTarget(named: "Alpha")
  }

  // MARK: - Test 2

  @MainActor
  func testSelectExistingTarget() throws {
    try skipOniOS18()
    launchApp()
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "Bravo")
    XCTAssertTrue(setup.isDisplayed)

    // Go back to list
    let listPage: TargetListPage
    if !isIPad {
      listPage = setup.navigateBackToList()
    } else {
      listPage = list
    }

    // Select the target
    let reloaded = listPage.selectTarget(named: "Bravo")
    let nameField = reloaded.targetNameField
    XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Target name field should appear")
    XCTAssertEqual(nameField.value as? String, "Bravo", "Target name should be 'Bravo'")

    // Clean up
    listPage.deleteTarget(named: "Bravo")
  }

  // MARK: - Test 3

  @MainActor
  func testDeleteTargetRemovesFromList() throws {
    launchApp()
    let list = TargetListPage(app: app)

    // Create Charlie
    let setup1 = list.createTarget(named: "Charlie")
    let list1: TargetListPage
    if !isIPad {
      list1 = setup1.navigateBackToList()
    } else {
      list1 = list
    }

    // Create Delta
    let setup2 = list1.createTarget(named: "Delta")
    let list2: TargetListPage
    if !isIPad {
      list2 = setup2.navigateBackToList()
    } else {
      list2 = list1
    }

    // Delete Charlie
    list2.deleteTarget(named: "Charlie")

    // Assert Delta remains (check this first since Charlie lookup has a 5s timeout)
    let deltaText = app.staticTexts["Delta"]
    XCTAssertTrue(deltaText.waitForExistence(timeout: 10), "Delta should remain in list")

    // Assert Charlie is gone — wait for its cell to leave the list rather than
    // relying on a fixed settle after the delete animation.
    let charlieText = app.staticTexts["Charlie"]
    XCTAssertTrue(
      charlieText.waitForNonExistence(timeout: 5),
      "Charlie should be deleted"
    )

    // Clean up
    list2.deleteTarget(named: "Delta")
  }

  // MARK: - Test 4

  @MainActor
  func testTargetListShowsCoordinates() throws {
    try skipOniOS18()
    launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "CoordTarget")

    // Enter DD coordinates
    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("DD")
    coordPage.enterLatLon(
      lat: (direction: "N", digits: "37.12345"),
      lon: (direction: "W", digits: "121.67890")
    )
    let setupReturned = coordPage.tapAccept()
    XCTAssertTrue(setupReturned.isDisplayed)

    // Navigate to list
    let listPage: TargetListPage
    if !isIPad {
      listPage = setupReturned.navigateBackToList()
    } else {
      listPage = list
    }

    // Assert cell displays coordinate text (format varies based on user preference)
    let cell = listPage.targetCell(named: "CoordTarget")
    XCTAssertNotNil(cell, "Target cell should exist")
    if let cell {
      // Look for a text containing "37" (latitude) and "121" (longitude)
      // The format may be DD (37.12345°), DMS (37° 07′ 24″), etc.
      let predicate = NSPredicate(format: "label CONTAINS '37' AND label CONTAINS '121'")
      let coordText = cell.staticTexts.element(matching: predicate)
      XCTAssertTrue(
        coordText.waitForExistence(timeout: 5),
        "Cell should show coordinates containing '37' and '121'"
      )
    }

    // Clean up
    listPage.deleteTarget(named: "CoordTarget")
  }

  // MARK: - Test 5

  @MainActor
  func testTargetListShowsTimeOnTarget() throws {
    try skipOniOS18()
    launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "TOTListTarget")

    // Navigate through IP setup to TOT
    let ipPage = setup.tapDefineIP()
    ipPage.enterBearing("090")
    ipPage.enterOffsetDistance("5")
    let totPage = ipPage.tapTimeOnTarget()
    totPage.selectZuluTime()
    totPage.enterTime("18:00:00")

    // Navigate back to list via nav bar back buttons
    if !isIPad {
      for _ in 0..<5 {
        let addTarget = app.buttons["addTargetButton"]
        if addTarget.waitForExistence(timeout: 1) { break }
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        guard backButton.waitForExistence(timeout: 3) else { break }
        if backButton.isHittable {
          backButton.tap()
        } else {
          backButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        Thread.sleep(forTimeInterval: 0.5)
      }
    }

    let listPage = TargetListPage(app: app)
    XCTAssertTrue(listPage.isDisplayed)

    // Assert cell contains time text
    let cell = listPage.targetCell(named: "TOTListTarget")
    XCTAssertNotNil(cell, "Target cell should exist")
    if let cell {
      let timePredicate = NSPredicate(format: "label CONTAINS '1800' AND label CONTAINS[c] 'Z'")
      let timeText = cell.staticTexts.element(matching: timePredicate)
      XCTAssertTrue(timeText.exists, "Cell should show time containing '1800Z'")
    }

    // Clean up
    listPage.deleteTarget(named: "TOTListTarget")
  }

  // MARK: - Test 6

  @MainActor
  func testEmptyStateShowsNoTarget() throws {
    launchApp()
    guard isIPad else {
      throw XCTSkip("Empty state detail pane only visible on iPad")
    }

    // With no target selected, the detail pane should show "No Target"
    let noTargetText = app.staticTexts["No Target"]
    XCTAssertTrue(
      noTargetText.waitForExistence(timeout: 5),
      "'No Target' should be displayed in detail pane"
    )
  }
}

// swiftlint:enable prefer_nimble
