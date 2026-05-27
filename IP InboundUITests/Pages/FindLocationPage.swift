import XCTest

// swiftlint:disable prefer_nimble

struct FindLocationPage: Page {
  let app: XCUIApplication

  @MainActor var isDisplayed: Bool {
    // The identifier sits on a SwiftUI `List`, which XCUITest exposes as a collection view.
    app.collectionViews["findLocationView"].waitForExistence(timeout: 5)
  }

  @MainActor var searchField: XCUIElement { app.searchFields.firstMatch }

  // Suggestions live in the `findLocationView`-tagged List (a UICollectionView
  // under SwiftUI). Scope the cell query so the iPad sidebar's target cells
  // — also `XCUIElement.cell` — don't shadow the first match.
  @MainActor private var suggestionList: XCUIElementQuery {
    app.collectionViews["findLocationView"].cells
  }

  @MainActor var hasSuggestions: Bool {
    suggestionList.count > 0  // swiftlint:disable:this empty_count
  }

  @MainActor var firstSuggestion: XCUIElement { suggestionList.firstMatch }

  // MARK: - Actions

  @MainActor
  func search(for query: String) {
    XCTAssertTrue(searchField.waitForExistence(timeout: 3), "Search field should appear")
    forceTap(searchField)
    searchField.typeText(query)
  }

  @MainActor
  @discardableResult
  func selectFirstSuggestion() -> TargetSetupPage {
    let cell = suggestionList.firstMatch
    XCTAssertTrue(cell.waitForExistence(timeout: 10), "Suggestion should appear")
    forceTap(cell)
    return TargetSetupPage(app: app)
  }

  @MainActor
  @discardableResult
  func selectSuggestion(containing text: String) -> TargetSetupPage {
    let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
    let match = suggestionList.containing(predicate).firstMatch
    XCTAssertTrue(
      match.waitForExistence(timeout: 10),
      "Suggestion containing '\(text)' should appear"
    )
    forceTap(match)
    return TargetSetupPage(app: app)
  }
}

// swiftlint:enable prefer_nimble
