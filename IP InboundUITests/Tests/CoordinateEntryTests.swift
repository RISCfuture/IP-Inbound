import XCTest

// swiftlint:disable prefer_nimble

final class CoordinateEntryTests: BaseTestCase {

  // MARK: - Test 7

  func testCoordinateEntry_DecimalDegrees() async throws {
    await launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "DD Test")

    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("DD")
    await coordPage.enterLatLon(
      lat: (direction: "N", digits: "37.12345"),
      lon: (direction: "W", digits: "121.67890")
    )
    let returned = coordPage.tapAccept()
    XCTAssertTrue(returned.isDisplayed)

    let label = returned.coordinatesLabel()
    XCTAssertTrue(label.contains("N 37.12345°"), "Latitude should be N 37.12345° but was: \(label)")
    XCTAssertTrue(
      label.contains("W 121.67890°"),
      "Longitude should be W 121.67890° but was: \(label)"
    )

    navigateToListAndDelete("DD Test")
  }

  // MARK: - Test 8

  func testCoordinateEntry_DegreesMinutesSeconds() async throws {
    await launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "DMS Test")

    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("DMS")
    await coordPage.enterLatLon(
      lat: (direction: "N", digits: "37 12 34"),
      lon: (direction: "W", digits: "121 23 45")
    )
    let returned = coordPage.tapAccept()
    XCTAssertTrue(returned.isDisplayed)

    let label = returned.coordinatesLabel()
    XCTAssertTrue(
      label.contains("N 37° 12′ 34″"),
      "Latitude should be N 37° 12′ 34″ but was: \(label)"
    )
    XCTAssertTrue(
      label.contains("W 121° 23′ 45″"),
      "Longitude should be W 121° 23′ 45″ but was: \(label)"
    )

    navigateToListAndDelete("DMS Test")
  }

  // MARK: - Test 9

  func testCoordinateEntry_DegreesDecimalMinutes() async throws {
    await launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "DDM Test")

    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("DDM")
    await coordPage.enterLatLon(
      lat: (direction: "N", digits: "37 12.345"),
      lon: (direction: "W", digits: "121 23.456")
    )
    let returned = coordPage.tapAccept()
    XCTAssertTrue(returned.isDisplayed)

    let label = returned.coordinatesLabel()
    XCTAssertTrue(
      label.contains("N 37° 12.345′"),
      "Latitude should be N 37° 12.345′ but was: \(label)"
    )
    XCTAssertTrue(
      label.contains("W 121° 23.456′"),
      "Longitude should be W 121° 23.456′ but was: \(label)"
    )

    navigateToListAndDelete("DDM Test")
  }

  // MARK: - Test 10

  func testCoordinateEntry_UTM() async throws {
    await launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "UTM Test")

    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("UTM")
    coordPage.enterGridCoordinate("10S 551000 418900")
    let returned = coordPage.tapAccept()
    XCTAssertTrue(returned.isDisplayed)

    let label = returned.coordinatesLabel()
    XCTAssertTrue(label.contains("10S"), "UTM label should contain '10S' but was: \(label)")

    navigateToListAndDelete("UTM Test")
  }

  // MARK: - Test 11

  func testCoordinateEntry_MGRS() async throws {
    await launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "MGRS Test")

    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("MGRS")
    coordPage.enterGridCoordinate("12U UA 84323 40791")
    let returned = coordPage.tapAccept()
    XCTAssertTrue(returned.isDisplayed)

    let label = returned.coordinatesLabel()
    XCTAssertTrue(label.contains("12U"), "MGRS label should contain '12U' but was: \(label)")
    XCTAssertFalse(
      label.contains("10S"),
      "MGRS should not show initial location 10S, was: \(label)"
    )

    navigateToListAndDelete("MGRS Test")
  }

  // MARK: - Test 12

  func testCoordinateEntry_SouthEastHemisphere() async throws {
    await launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "SE Test")

    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("DD")
    await coordPage.enterLatLon(
      lat: (direction: "S", digits: "33.86880"),
      lon: (direction: "E", digits: "151.20930")
    )
    let returned = coordPage.tapAccept()
    XCTAssertTrue(returned.isDisplayed)

    let label = returned.coordinatesLabel()
    XCTAssertTrue(label.contains("S 33.86880°"), "Latitude should be S 33.86880° but was: \(label)")
    XCTAssertTrue(
      label.contains("E 151.20930°"),
      "Longitude should be E 151.20930° but was: \(label)"
    )

    navigateToListAndDelete("SE Test")
  }

  // MARK: - Test 13

  func testCoordinateDisplay_TapCyclesFormat() async throws {
    await launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "Cycle Test")

    // Enter DD coordinates
    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("DD")
    await coordPage.enterLatLon(
      lat: (direction: "N", digits: "37.12345"),
      lon: (direction: "W", digits: "121.67890")
    )
    let returned = coordPage.tapAccept()
    XCTAssertTrue(returned.isDisplayed)

    // Starting format is decimal degrees, which uses the degree symbol.
    let degreeSymbol = "°"
    let label1 = returned.coordinatesLabel()
    XCTAssertTrue(
      label1.contains(degreeSymbol),
      "Initial label should be decimal degrees but was: '\(label1)'"
    )

    // First tap cycles DD → UTM. Wait for the label to actually change rather
    // than sleeping a fixed interval, then verify it advanced to a grid format
    // (zone-based, no degree symbol).
    returned.tapCoordinatesToCycleFormat()
    let label2 = waitForCoordinatesLabelToChange(from: label1, on: returned)
    XCTAssertNotEqual(label1, label2, "First tap should advance the coordinate format")
    XCTAssertFalse(
      label2.contains(degreeSymbol),
      "After cycling to UTM the label should be a grid format but was: '\(label2)'"
    )

    // Second tap cycles UTM → MGRS, another distinct grid format.
    returned.tapCoordinatesToCycleFormat()
    let label3 = waitForCoordinatesLabelToChange(from: label2, on: returned)
    XCTAssertNotEqual(label2, label3, "Second tap should advance the coordinate format")
    XCTAssertFalse(
      label3.contains(degreeSymbol),
      "After cycling to MGRS the label should be a grid format but was: '\(label3)'"
    )

    navigateToListAndDelete("Cycle Test")
  }

  // MARK: - Helper

  // Waits until the displayed coordinates label differs from `previous`
  // (e.g. after a format-cycle tap) and returns the new value. Returns the
  // last observed value if it never changes within the timeout.
  private func waitForCoordinatesLabelToChange(
    from previous: String,
    on page: TargetSetupPage,
    timeout: TimeInterval = 5
  ) -> String {
    let coords = app.buttons["targetCoordinates"]
    let changed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label != %@", previous),
      object: coords
    )
    _ = XCTWaiter.wait(for: [changed], timeout: timeout)
    return page.coordinatesLabel()
  }

  private func navigateToListAndDelete(_ name: String) {
    let setup = TargetSetupPage(app: app)
    if !isIPad {
      _ = setup.navigateBackToList()
    }
    TargetListPage(app: app).deleteTarget(named: name)
  }
}

// swiftlint:enable prefer_nimble
