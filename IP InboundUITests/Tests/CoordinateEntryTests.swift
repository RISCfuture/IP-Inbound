import XCTest

// swiftlint:disable prefer_nimble

final class CoordinateEntryTests: BaseTestCase {

  // MARK: - Test 7

  @MainActor
  func testCoordinateEntry_DecimalDegrees() throws {
    try skipOniOS18()
    launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "DD Test")

    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("DD")
    coordPage.enterLatLon(
      lat: (direction: "N", digits: "37.12345"),
      lon: (direction: "W", digits: "121.67890")
    )
    let returned = coordPage.tapAccept()
    XCTAssertTrue(returned.isDisplayed)

    let label = returned.coordinatesLabel()
    XCTAssertTrue(label.contains("N 37.12345°"), "Latitude should be N 37.12345° but was: \(label)")
    XCTAssertTrue(label.contains("W 121.67890°"), "Longitude should be W 121.67890° but was: \(label)")

    navigateToListAndDelete("DD Test")
  }

  // MARK: - Test 8

  @MainActor
  func testCoordinateEntry_DegreesMinutesSeconds() throws {
    try skipOniOS18()
    launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "DMS Test")

    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("DMS")
    coordPage.enterLatLon(
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

  @MainActor
  func testCoordinateEntry_DegreesDecimalMinutes() throws {
    try skipOniOS18()
    launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "DDM Test")

    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("DDM")
    coordPage.enterLatLon(
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

  @MainActor
  func testCoordinateEntry_UTM() throws {
    try skipOniOS18()
    launchApp()

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

  @MainActor
  func testCoordinateEntry_MGRS() throws {
    try skipOniOS18()
    launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "MGRS Test")

    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("MGRS")
    coordPage.enterGridCoordinate("12U UA 84323 40791")
    let returned = coordPage.tapAccept()
    XCTAssertTrue(returned.isDisplayed)

    let label = returned.coordinatesLabel()
    XCTAssertTrue(label.contains("12U"), "MGRS label should contain '12U' but was: \(label)")
    XCTAssertFalse(label.contains("10S"), "MGRS should not show initial location 10S, was: \(label)")

    navigateToListAndDelete("MGRS Test")
  }

  // MARK: - Test 12

  @MainActor
  func testCoordinateEntry_SouthEastHemisphere() throws {
    try skipOniOS18()
    launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "SE Test")

    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("DD")
    coordPage.enterLatLon(
      lat: (direction: "S", digits: "33.86880"),
      lon: (direction: "E", digits: "151.20930")
    )
    let returned = coordPage.tapAccept()
    XCTAssertTrue(returned.isDisplayed)

    let label = returned.coordinatesLabel()
    XCTAssertTrue(label.contains("S 33.86880°"), "Latitude should be S 33.86880° but was: \(label)")
    XCTAssertTrue(label.contains("E 151.20930°"), "Longitude should be E 151.20930° but was: \(label)")

    navigateToListAndDelete("SE Test")
  }

  // MARK: - Test 13

  @MainActor
  func testCoordinateDisplay_TapCyclesFormat() throws {
    try skipOniOS18()
    launchApp()

    let list = TargetListPage(app: app)
    let setup = list.createTarget(named: "Cycle Test")

    // Enter DD coordinates
    let coordPage = setup.tapSetCoordinates()
    coordPage.selectFormat("DD")
    coordPage.enterLatLon(
      lat: (direction: "N", digits: "37.12345"),
      lon: (direction: "W", digits: "121.67890")
    )
    let returned = coordPage.tapAccept()
    XCTAssertTrue(returned.isDisplayed)

    let label1 = returned.coordinatesLabel()

    // Tap to cycle format
    returned.tapCoordinatesToCycleFormat()
    // Brief wait for UI update
    Thread.sleep(forTimeInterval: 0.5)
    let label2 = returned.coordinatesLabel()

    // Tap again
    returned.tapCoordinatesToCycleFormat()
    Thread.sleep(forTimeInterval: 0.5)
    let label3 = returned.coordinatesLabel()

    // At least one of the subsequent labels should differ from the first
    let changed = (label1 != label2) || (label2 != label3)
    XCTAssertTrue(changed, "Tapping coordinates should cycle format. Got: '\(label1)', '\(label2)', '\(label3)'")

    navigateToListAndDelete("Cycle Test")
  }

  // MARK: - Helper

  @MainActor
  private func navigateToListAndDelete(_ name: String) {
    let setup = TargetSetupPage(app: app)
    if !isIPad {
      _ = setup.navigateBackToList()
    }
    TargetListPage(app: app).deleteTarget(named: name)
  }
}

// swiftlint:enable prefer_nimble
