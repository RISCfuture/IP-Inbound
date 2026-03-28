import XCTest

// swiftlint:disable prefer_nimble

final class TOTEntryTests: BaseTestCase {

  // MARK: - Test 14

  @MainActor
  func testTimeEntry_Local() throws {
    try skipOniOS18()
    launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "Local Time Test")

    let ipPage = setup.tapDefineIP()
    ipPage.enterBearing("090")
    ipPage.enterOffsetDistance("5")
    let totPage = ipPage.tapTimeOnTarget()

    totPage.selectLocalTime()
    totPage.enterTime("12:34:56")

    // Navigate back to list
    navigateFromTOTToList()

    let listPage = TargetListPage(app: app)
    XCTAssertTrue(listPage.isDisplayed)

    // Cell should show a time value (either local format like "12:34 PM" or Zulu like "1934Z")
    XCTAssertNotNil(listPage.targetCell(named: "Local Time Test"), "Target cell should exist")
    let hasTime = listPage.cellContainsTimeText(named: "Local Time Test")
    XCTAssertTrue(hasTime, "Cell should contain a time display")

    listPage.deleteTarget(named: "Local Time Test")
  }

  // MARK: - Test 15

  @MainActor
  func testTimeEntry_Zulu() throws {
    try skipOniOS18()
    launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "Zulu Time Test")

    let ipPage = setup.tapDefineIP()
    ipPage.enterBearing("090")
    ipPage.enterOffsetDistance("5")
    let totPage = ipPage.tapTimeOnTarget()

    totPage.selectZuluTime()
    totPage.enterTime("18:00:00")

    // Navigate back to list
    navigateFromTOTToList()

    let listPage = TargetListPage(app: app)
    XCTAssertTrue(listPage.isDisplayed)

    let cell = listPage.targetCell(named: "Zulu Time Test")
    XCTAssertNotNil(cell, "Target cell should exist")
    if let cell {
      let timePredicate = NSPredicate(format: "label CONTAINS '1800' AND label CONTAINS[c] 'Z'")
      let timeText = cell.staticTexts.element(matching: timePredicate)
      XCTAssertTrue(timeText.exists, "Cell should show '1800Z'")
    }

    listPage.deleteTarget(named: "Zulu Time Test")
  }

  // MARK: - Test 16

  @MainActor
  func testTimeEntry_ToggleBetweenLocalAndZulu() throws {
    try skipOniOS18()
    launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "Toggle Test")

    let ipPage = setup.tapDefineIP()
    ipPage.enterBearing("090")
    ipPage.enterOffsetDistance("5")
    let totPage = ipPage.tapTimeOnTarget()

    totPage.selectZuluTime()
    totPage.enterTime("18:00:00")

    // Read secondary time string
    let zuluSecondary = totPage.secondaryTimeString()

    // Switch to local
    totPage.selectLocalTime()
    Thread.sleep(forTimeInterval: 0.5)

    let localSecondary = totPage.secondaryTimeString()

    // The secondary string should change (different timezone abbreviation)
    XCTAssertNotEqual(
      zuluSecondary,
      localSecondary,
      "Secondary time should change when toggling. Zulu: '\(zuluSecondary)', Local: '\(localSecondary)'"
    )

    // Clean up
    navigateFromTOTToList()
    TargetListPage(app: app).deleteTarget(named: "Toggle Test")
  }

  // MARK: - Test 17

  @MainActor
  func testTimeEntry_DefaultTimeIsSet() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "Default TOT Test")

    let ipPage = setup.tapDefineIP()
    ipPage.enterBearing("090")
    ipPage.enterOffsetDistance("5")
    let totPage = ipPage.tapTimeOnTarget()

    // The time entry field should display a non-zero time (30-minute default)
    let entryField = totPage.timeEntryField
    XCTAssertTrue(entryField.waitForExistence(timeout: 3), "Time entry field should appear")
    let label = entryField.label
    XCTAssertFalse(label.isEmpty, "Time entry should display a default time")
    // Verify it's not all zeros
    let stripped = label.replacingOccurrences(of: ":", with: "").replacingOccurrences(
      of: " ",
      with: ""
    )
    let allZeros = stripped.allSatisfy { $0 == "0" }
    XCTAssertFalse(allZeros, "Default time should not be all zeros, was: \(label)")

    // Clean up
    navigateFromTOTToList()
    TargetListPage(app: app).deleteTarget(named: "Default TOT Test")
  }

  // MARK: - Helper

  @MainActor
  private func navigateFromTOTToList() {
    if !isIPad {
      // Keep tapping back until we reach the target list
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
  }
}

// swiftlint:enable prefer_nimble
