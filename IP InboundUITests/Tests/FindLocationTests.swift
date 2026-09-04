import XCTest

// swiftlint:disable prefer_nimble

// Exercises the Find-Location search/select flow reached from target setup.
//
// Limitation: the production search path (`SearchCompleter`/`FindLocationView`)
// drives live `MKLocalSearchCompleter` and `MKLocalSearch`, and the app exposes
// no injection for search RESULTS (only location *fixes* are injectable via
// `UITEST_LOCATION`). These tests therefore depend on live MapKit returning
// suggestions for a well-known query. Where results are unavailable the test
// asserts on deterministic UI behavior (search field focus, suggestions list
// population) rather than on a specific place, and the selection assertion
// checks that the target *changed* from its seeded value rather than matching
// an exact MapKit-provided string.
final class FindLocationTests: BaseTestCase {

  // MARK: - Type Properties

  private static let searchQuery = "San Francisco International Airport"
  private static let seededTargetName = "New Target"

  // MARK: - Test: search populates suggestions

  @MainActor
  func testFindLocation_SearchPopulatesSuggestions() async throws {
    await launchApp()

    let setup = TargetListPage(app: app).createTarget(named: "Find Suggestions")
    let findLocation = setup.tapFindLocation()
    XCTAssertTrue(findLocation.isDisplayed, "Find Location sheet should appear")

    findLocation.search(for: Self.searchQuery)

    XCTAssertTrue(
      findLocation.firstSuggestion.waitForExistence(timeout: 15),
      "Searching for a well-known place should populate the suggestions list"
    )
    XCTAssertTrue(findLocation.hasSuggestions, "Suggestions list should be non-empty after search")
  }

  // MARK: - Test: selecting a suggestion updates the target

  @MainActor
  func testFindLocation_SelectingSuggestionUpdatesTarget() async throws {
    await launchApp()

    let setup = TargetListPage(app: app).createTarget(named: "Find Select")

    // A new target seeds its coordinate from the current location fix
    // (San Francisco, per `defaultFix`), so capture that baseline to prove the
    // selection actually changed the target rather than merely existing.
    let seededCoordinates = setup.coordinatesLabel()

    let findLocation = setup.tapFindLocation()
    XCTAssertTrue(findLocation.isDisplayed, "Find Location sheet should appear")

    findLocation.search(for: Self.searchQuery)
    // Confirm a real suggestion landed in the list before tapping; otherwise
    // `selectFirstSuggestion` would tap whatever fallback cell XCUITest
    // returns and the geocode never fires, producing an unactionable assertion
    // failure ("coords didn't change") that we'd misread as a real bug.
    try XCTSkipUnless(
      findLocation.firstSuggestion.waitForExistence(timeout: 15),
      "MapKit did not return a suggestion within 15s — skipping (test depends on live MKLocalSearchCompleter)"
    )
    let returned = findLocation.selectFirstSuggestion()
    XCTAssertTrue(
      returned.isDisplayed,
      "Should return to target setup after selecting a suggestion"
    )

    // The selected suggestion's title becomes the target name, and its
    // coordinate replaces the seeded one. Wait for the coordinate label to
    // change (the lookup is asynchronous), then assert both fields reflect the
    // selection.
    let updatedCoordinates = waitForCoordinatesLabelToChange(from: seededCoordinates, on: returned)
    XCTAssertNotEqual(
      seededCoordinates,
      updatedCoordinates,
      "Selecting a location should replace the seeded coordinate"
    )

    let updatedName = nameFieldValue()
    XCTAssertFalse(updatedName.isEmpty, "Target name should be populated from the selection")
    XCTAssertNotEqual(
      updatedName,
      Self.seededTargetName,
      "Selecting a location should replace the seeded target name"
    )
  }

  // MARK: - Helpers

  // Waits until the displayed coordinates label differs from `previous`
  // (the coordinate lookup is asynchronous) and returns the new value.
  // Returns the last observed value if it never changes within the timeout.
  @MainActor
  private func waitForCoordinatesLabelToChange(
    from previous: String,
    on page: TargetSetupPage,
    timeout: TimeInterval = 30
  ) -> String {
    let coords = app.buttons["targetCoordinates"]
    let changed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label != %@", previous),
      object: coords
    )
    _ = XCTWaiter.wait(for: [changed], timeout: timeout)
    return page.coordinatesLabel()
  }

  @MainActor
  private func nameFieldValue() -> String {
    let field = app.textFields["targetNameField"]
    XCTAssertTrue(field.waitForExistence(timeout: 5), "Target name field should exist")
    return (field.value as? String) ?? ""
  }
}

// swiftlint:enable prefer_nimble
