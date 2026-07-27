import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

struct FindLocationPage: Page {
  let app: XCUIApplication

  var isDisplayed: Bool {
    // The identifier sits on a SwiftUI `List`, which XCUITest exposes as a collection view.
    app.collectionViews["findLocationView"].waitForExistence(timeout: 5)
  }

  var searchField: XCUIElement { app.searchFields.firstMatch }

  // Suggestions live in the `findLocationView`-tagged List (a UICollectionView
  // under SwiftUI). Scope the cell query so the iPad sidebar's target cells
  // — also `XCUIElement.cell` — don't shadow the first match.
  private var suggestionList: XCUIElementQuery {
    app.collectionViews["findLocationView"].cells
  }

  var hasSuggestions: Bool {
    suggestionList.count > 0  // swiftlint:disable:this empty_count
  }

  var firstSuggestion: XCUIElement { suggestionList.firstMatch }

  // MARK: - Actions

  func search(for query: String) {
    XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Search field should appear")
    searchField.forceTap()
    searchField.typeText(query)
  }

  @discardableResult
  func selectFirstSuggestion() -> TargetSetupPage {
    let cell = suggestionList.firstMatch
    XCTAssertTrue(cell.waitForExistence(timeout: 10), "Suggestion should appear")
    cell.forceTap()
    return TargetSetupPage(app: app)
  }

  @discardableResult
  func selectSuggestion(containing text: String) -> TargetSetupPage {
    let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
    let match = suggestionList.containing(predicate).firstMatch
    XCTAssertTrue(
      match.waitForExistence(timeout: 10),
      "Suggestion containing '\(text)' should appear"
    )
    match.forceTap()
    return TargetSetupPage(app: app)
  }
}

// swiftlint:enable prefer_nimble
