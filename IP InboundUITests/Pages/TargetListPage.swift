import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

struct TargetListPage: Page {
  /// The share of the window's width below which the target list is a sidebar beside a detail pane.
  private static let sidebarWidthFraction = 0.75

  let app: XCUIApplication

  var isDisplayed: Bool {
    app.buttons["addTargetButton"].waitForExistence(timeout: 15)
  }

  var listView: XCUIElement { app.descendant(id: "targetList") }
  var addTargetButton: XCUIElement { app.buttons["addTargetButton"] }
  var tutorialButton: XCUIElement { app.buttons["tutorialButton"] }

  var targetCount: Int {
    app.cells.count
  }

  /**
   Whether the target list sits in a sidebar beside a detail pane rather than filling the window.

   Read from the layout rather than the device idiom: iPhone Duo's inner display lays the app out
   in two panes while still reporting itself a phone. Only meaningful while the list is on screen.
   */
  var isBesideDetail: Bool {
    let list = listView.frame.width
    let window = app.windows.firstMatch.frame.width
    return list < window * Self.sidebarWidthFraction
  }

  // MARK: - Methods

  @discardableResult
  func tapAddTarget() -> TargetSetupPage {
    XCTAssertTrue(addTargetButton.waitForExistence(timeout: 15), "addTargetButton should appear")
    addTargetButton.forceTap()
    return TargetSetupPage(app: app)
  }

  @discardableResult
  func createTarget(named name: String) -> TargetSetupPage {
    let setupPage = tapAddTarget()
    XCTAssertTrue(setupPage.isDisplayed, "Target setup page should appear")
    setupPage.enterTargetName(name)
    return setupPage
  }

  @discardableResult
  func tapTutorial() -> TutorialPage {
    XCTAssertTrue(tutorialButton.waitForExistence(timeout: 5), "tutorialButton should appear")
    let tutorialTitle = app.staticTexts["How to Use IP Inbound"]
    // Try tapping the button up to 3 times (may fail if another app interrupts)
    for attempt in 0..<3 {
      if attempt > 0 {
        // Re-activate our app in case another app stole focus, then wait for it
        // to return to the foreground rather than sleeping a fixed interval.
        app.activate()
        _ = app.wait(for: .runningForeground, timeout: 5)
      }
      if tutorialButton.isHittable {
        tutorialButton.tap()
      } else {
        // Fallback: tap via coordinate to bypass hittability check
        tutorialButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
      }
      if tutorialTitle.waitForExistence(timeout: 3) { break }
    }
    return TutorialPage(app: app)
  }

  @discardableResult
  func selectTarget(named name: String) -> TargetSetupPage {
    let cell = targetCell(named: name)
    XCTAssertNotNil(cell, "Target '\(name)' should exist in list")
    if let cell { cell.forceTap() }
    return TargetSetupPage(app: app)
  }

  /// Pop the master navigation stack back to the target list, one nav-bar back
  /// tap at a time, until `addTargetButton` is showing. A list in a sidebar beside
  /// the detail is already showing, unless the Fly screen has hidden the sidebar,
  /// which leaving it restores. Each iteration waits for the next state rather than
  /// sleeping a fixed interval: `addTargetButton.waitForExistence` is the loop's settle.
  @discardableResult
  func navigateBackToList() -> Self {
    for _ in 0..<6 {
      if addTargetButton.waitForExistence(timeout: 1) { break }
      let backButton = app.buttons["BackButton"]
      guard backButton.waitForExistence(timeout: 3) else { break }
      if backButton.isHittable {
        backButton.tap()
      } else {
        backButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
      }
    }
    return self
  }

  func deleteTarget(named name: String) {
    // Match the swipe-action Delete button only — exclude the numeric/coordinate
    // keypad's backspace (accessibilityIdentifier `keypad-Delete`, label "Delete"),
    // which stays in the iPad split-view detail pane during sidebar cleanup.
    let swipeActionDelete = NSPredicate(
      format: "label == %@ AND NOT (identifier BEGINSWITH %@)",
      "Delete",
      "keypad-"
    )
    var iterations = 0
    while iterations < 5 {
      iterations += 1
      guard let cell = findCell(named: name) else { break }
      // On iPad, sidebar cells may have empty visible frame — use coordinate-based swipe
      let start = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
      let end = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
      start.press(forDuration: 0.1, thenDragTo: end)
      let deleteButton = app.buttons.matching(swipeActionDelete).firstMatch
      if deleteButton.waitForExistence(timeout: 2) {
        deleteButton.tap()
        _ = deleteButton.waitForNonExistence(timeout: 2)
        // Wait for the removed row's text to leave the hierarchy (the deletion
        // animation finishing) rather than sleeping a fixed interval before
        // re-querying for any remaining duplicate.
        _ = app.staticTexts[name].firstMatch.waitForNonExistence(timeout: 2)
      }
    }
  }

  func targetCell(named name: String) -> XCUIElement? {
    findCell(named: name)
  }

  func cellContainsTimeText(named name: String) -> Bool {
    guard let cell = targetCell(named: name) else { return false }
    // swiftlint:disable:next force_try
    let timePattern = try! NSRegularExpression(pattern: #"\d{1,2}:\d{2}(\s*(AM|PM|am|pm))?"#)
    for i in 0..<cell.staticTexts.count {
      let label = cell.staticTexts.element(boundBy: i).label
      if timePattern.firstMatch(in: label, range: NSRange(label.startIndex..., in: label)) != nil {
        return true
      }
    }
    return false
  }

  // MARK: - Private

  private func findCell(named name: String) -> XCUIElement? {
    let nameText = app.staticTexts[name].firstMatch
    guard nameText.waitForExistence(timeout: 5) else { return nil }
    for i in 0..<app.cells.count {
      let cell = app.cells.element(boundBy: i)
      if cell.staticTexts[name].exists {
        return cell
      }
    }
    return nil
  }
}

// swiftlint:enable prefer_nimble
