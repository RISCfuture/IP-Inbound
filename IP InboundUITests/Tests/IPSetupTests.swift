import XCTest

// swiftlint:disable prefer_nimble

final class IPSetupTests: BaseTestCase {

  // MARK: - Test 18

  func testBearingEntry_UpdatesInboundTrack() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "Bearing Test")
    let ipPage = setup.tapDefineIP()

    ipPage.enterBearing("180")

    // Dismiss keyboard by tapping elsewhere
    app.collectionViews.firstMatch.tap()

    // Wait for the inbound label to populate with a computed value rather than
    // sleeping a fixed interval before reading it.
    let inboundLabel = app.staticTexts.element(
      matching: NSPredicate(format: "label BEGINSWITH 'Inbound:'")
    )
    XCTAssertTrue(
      inboundLabel.waitForExistence(timeout: 5),
      "Inbound label should appear after entering bearing"
    )

    let inbound = ipPage.inboundLabel()
    XCTAssertNotNil(inbound, "Inbound label should be visible")
    XCTAssertEqual(
      inbound?.contains("Inbound:"),
      true,
      "Inbound label should show a computed value, got: \(inbound ?? "nil")"
    )
    // Should not be empty after the "Inbound:" prefix
    let value = inbound?.replacingOccurrences(of: "Inbound:", with: "").trimmingCharacters(
      in: .whitespaces
    )
    XCTAssertNotEqual(value?.isEmpty, true, "Inbound value should not be empty")

    navigateFromIPToListAndDelete("Bearing Test")
  }

  // MARK: - Test 19

  func testBearingReference_ChangesInboundValue() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "BearingRef Test")
    let ipPage = setup.tapDefineIP()

    ipPage.enterBearing("180")
    // Dismiss keyboard
    app.collectionViews.firstMatch.tap()

    // Wait for the inbound label to populate before reading the magnetic value.
    let inboundElement = app.staticTexts.element(
      matching: NSPredicate(format: "label BEGINSWITH 'Inbound:'")
    )
    XCTAssertTrue(inboundElement.waitForExistence(timeout: 5), "Inbound label should appear")

    // Read inbound with magnetic (default)
    let inboundMagnetic = ipPage.inboundLabel()

    // Switch to true and wait for the inbound label to recompute to a value that
    // differs from the magnetic reading rather than sleeping a fixed interval.
    ipPage.selectBearingReference("°T")
    let inboundChanged = XCTNSPredicateExpectation(
      predicate: NSPredicate(
        format: "label BEGINSWITH 'Inbound:' AND label != %@",
        inboundMagnetic ?? ""
      ),
      object: inboundElement
    )
    XCTAssertEqual(
      XCTWaiter.wait(for: [inboundChanged], timeout: 5),
      .completed,
      "Inbound label should recompute after switching to a true bearing reference"
    )

    let inboundTrue = ipPage.inboundLabel()

    XCTAssertNotEqual(
      inboundMagnetic,
      inboundTrue,
      "Inbound value should change between magnetic and true. Magnetic: '\(inboundMagnetic ?? "nil")', True: '\(inboundTrue ?? "nil")'"
    )

    navigateFromIPToListAndDelete("BearingRef Test")
  }

  // MARK: - Test 20

  func testOffsetType_DistanceToTime() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "OffsetType Test")
    let ipPage = setup.tapDefineIP()

    // Distance field should be visible by default
    let distField = ipPage.offsetDistanceField
    XCTAssertTrue(
      distField.waitForExistence(timeout: 3),
      "Distance field should be visible initially"
    )

    // Switch to Time
    ipPage.selectOffsetType("Time")

    let timeField = ipPage.offsetTimeField
    XCTAssertTrue(
      timeField.waitForExistence(timeout: 3),
      "Time field should appear after switching"
    )
    // Wait for the distance field to be torn down rather than reading it after a
    // fixed sleep.
    XCTAssertTrue(
      ipPage.offsetDistanceField.waitForNonExistence(timeout: 3),
      "Distance field should be gone after switching to Time"
    )

    // Switch back to Distance
    ipPage.selectOffsetType("Distance")

    XCTAssertTrue(
      ipPage.offsetDistanceField.waitForExistence(timeout: 3),
      "Distance field should reappear"
    )

    navigateFromIPToListAndDelete("OffsetType Test")
  }

  // MARK: - Test 21

  func testOffsetType_ValueConversion() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "Conversion Test")
    let ipPage = setup.tapDefineIP()

    // Enter offset distance
    ipPage.enterOffsetDistance("5")
    // Commit the value before switching offset type. numberPad has no Return key
    // and the iPad form fits without scrolling, so the keyboard can't be
    // dismissed by tapping a blank area or swiping; moving focus to another
    // field ends editing and writes the binding.
    ipPage.commitOffsetDistance()
    let distanceCommitted = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value CONTAINS '5'"),
      object: ipPage.offsetDistanceField
    )
    XCTAssertEqual(
      XCTWaiter.wait(for: [distanceCommitted], timeout: 5),
      .completed,
      "Distance field should retain the entered value"
    )

    // Switch to Time
    ipPage.selectOffsetType("Time")

    // Time field should show a non-zero computed value. Wait for the field to
    // appear and then for a non-empty value rather than sleeping.
    let timeField = ipPage.offsetTimeField
    XCTAssertTrue(timeField.waitForExistence(timeout: 3), "Time field should appear")
    let timePopulated = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value != nil AND value != ''"),
      object: timeField
    )
    XCTAssertEqual(
      XCTWaiter.wait(for: [timePopulated], timeout: 5),
      .completed,
      "Time field should populate with a computed value"
    )
    let timeValue = timeField.value as? String ?? ""
    XCTAssertFalse(timeValue.isEmpty, "Time field should have a computed value")
    let numericValue = try XCTUnwrap(
      Double(timeValue),
      "Time field should hold a number, got: '\(timeValue)'"
    )
    XCTAssertGreaterThan(numericValue, 0, "Time equivalent should be non-zero")
    // 5 NM at the default 120 kt ground speed is 2.5 min. The field must round
    // to the nearest whole minute rather than surfacing the fractional
    // conversion (e.g. "2.5" or "37.000032").
    XCTAssertEqual(
      numericValue,
      numericValue.rounded(),
      "Offset time should be rounded to a whole number, got: '\(timeValue)'"
    )

    navigateFromIPToListAndDelete("Conversion Test")
  }

  // MARK: - Test 22

  func testGroundSpeedEntry_AffectsOffsetTime() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "Speed Test")
    let ipPage = setup.tapDefineIP()

    ipPage.enterBearing("180")
    ipPage.enterOffsetDistance("5")

    // Set speed to 120 and verify inbound label updates
    ipPage.enterGroundSpeed("120")
    // Dismiss keyboard, then wait for the inbound label to populate before
    // reading it.
    app.collectionViews.firstMatch.tap()
    let inboundElement = app.staticTexts.element(
      matching: NSPredicate(format: "label BEGINSWITH 'Inbound:'")
    )
    XCTAssertTrue(
      inboundElement.waitForExistence(timeout: 5),
      "Inbound label should appear with speed 120"
    )

    // Read inbound label with speed 120
    let inbound1 = ipPage.inboundLabel()
    XCTAssertNotNil(inbound1, "Inbound label should be visible with speed 120")

    // Switch to time view to verify time is computed
    ipPage.selectOffsetType("Time")

    let timeField = ipPage.offsetTimeField
    XCTAssertTrue(timeField.waitForExistence(timeout: 3), "Time field should appear")
    let timePopulated = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value != nil AND value != ''"),
      object: timeField
    )
    XCTAssertEqual(
      XCTWaiter.wait(for: [timePopulated], timeout: 5),
      .completed,
      "Time field should populate with a computed value"
    )
    let timeValue = timeField.value as? String ?? ""
    let numericTime = Double(timeValue) ?? 0
    XCTAssertGreaterThan(
      numericTime,
      0,
      "Offset time should be a positive number for 5 NM at 120 kts, got: '\(timeValue)'"
    )

    navigateFromIPToListAndDelete("Speed Test")
  }

  // MARK: - Test 23

  func testFullIPConfiguration() throws {
    launchApp()
    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "Full IP Test")
    let ipPage = setup.tapDefineIP()

    ipPage.enterBearing("359")
    ipPage.selectBearingReference("°T")
    ipPage.enterOffsetDistance("4.8")
    ipPage.enterGroundSpeed("120")

    let totPage = ipPage.tapTimeOnTarget()
    XCTAssertTrue(totPage.isDisplayed, "TOT page should load")

    // Verify time entry is functional (field should exist with default time)
    XCTAssertTrue(
      totPage.timeEntryField.waitForExistence(timeout: 3),
      "Time entry field should be functional"
    )

    // Clean up
    navigateToListAndDelete("Full IP Test")
  }

  // MARK: - Helper

  private func navigateFromIPToListAndDelete(_ name: String) {
    navigateToListAndDelete(name)
  }

  private func navigateToListAndDelete(_ name: String) {
    let list = TargetListPage(app: app)
    list.navigateBackToList()
    list.deleteTarget(named: name)
  }
}

// swiftlint:enable prefer_nimble
