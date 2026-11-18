import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

struct FindLocationPage: Page {
  let app: XCUIApplication

  var isDisplayed: Bool {
    // The identifier sits on a SwiftUI `List`, which XCUITest exposes as a collection view.
    app.collectionViews["findLocationView"].wait(timeout: 5)
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

  /// The first suggestion's label and the number of suggestions, which together change whenever
  /// the completer revises the list.
  private var suggestionsShown: String {
    let first = suggestionList.firstMatch
    return "\(suggestionList.count) \(first.exists ? first.label : "")"
  }

  // MARK: - Actions

  func search(for query: String) {
    XCTAssertTrue(searchField.wait(timeout: 3), "Search field should appear")
    searchField.forceTap()
    searchField.typeText(query)
  }

  @discardableResult
  func selectFirstSuggestion() -> TargetSetupPage {
    let cell = suggestionList.firstMatch
    XCTAssertTrue(cell.wait(timeout: 10), "Suggestion should appear")
    waitForSuggestionsToSettle()
    cell.forceTap()
    return TargetSetupPage(app: app)
  }

  /// Waits for live MapKit search to stop revising the suggestions. The completer rewrites the
  /// list as each keystroke's results arrive, and a tap that lands mid-rewrite selects a row that
  /// is replaced before its location is looked up.
  private func waitForSuggestionsToSettle(timeout: TimeInterval = 5) {
    let deadline = Date().addingTimeInterval(timeout)
    var listed = suggestionsShown
    while Date() < deadline {
      Thread.sleep(forTimeInterval: 0.5)
      let current = suggestionsShown
      if current == listed { return }
      listed = current
    }
  }

  @discardableResult
  func selectSuggestion(containing text: String) -> TargetSetupPage {
    let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
    let match = suggestionList.containing(predicate).firstMatch
    XCTAssertTrue(
      match.wait(timeout: 10),
      "Suggestion containing '\(text)' should appear"
    )
    match.forceTap()
    return TargetSetupPage(app: app)
  }
}

// swiftlint:enable prefer_nimble
