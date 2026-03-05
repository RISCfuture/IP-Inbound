import XCTest

// swiftlint:disable prefer_nimble

struct TargetListPage: Page {
  let app: XCUIApplication

  @MainActor var isDisplayed: Bool {
    app.buttons["addTargetButton"].waitForExistence(timeout: 15)
  }

  // MARK: - Elements

  @MainActor var addTargetButton: XCUIElement { app.buttons["addTargetButton"] }
  @MainActor var tutorialButton: XCUIElement { app.buttons["tutorialButton"] }

  // MARK: - Actions

  @MainActor
  @discardableResult
  func tapAddTarget() -> TargetSetupPage {
    XCTAssertTrue(addTargetButton.waitForExistence(timeout: 15), "addTargetButton should appear")
    addTargetButton.tap()
    return TargetSetupPage(app: app)
  }

  @MainActor
  @discardableResult
  func createTarget(named name: String) -> TargetSetupPage {
    let setupPage = tapAddTarget()
    setupPage.enterTargetName(name)
    return setupPage
  }

  @MainActor
  @discardableResult
  func tapTutorial() -> TutorialPage {
    XCTAssertTrue(tutorialButton.waitForExistence(timeout: 5), "tutorialButton should appear")
    let tutorialTitle = app.staticTexts["How to Use IP Inbound"]
    // Try tapping the button up to 3 times (may fail if another app interrupts)
    for attempt in 0..<3 {
      if attempt > 0 {
        // Re-activate our app in case another app stole focus
        app.activate()
        Thread.sleep(forTimeInterval: 0.5)
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

  @MainActor
  @discardableResult
  func selectTarget(named name: String) -> TargetSetupPage {
    let cell = targetCell(named: name)
    XCTAssertNotNil(cell, "Target '\(name)' should exist in list")
    cell?.tap()
    return TargetSetupPage(app: app)
  }

  @MainActor
  func deleteTarget(named name: String) {
    var iterations = 0
    while iterations < 5 {
      iterations += 1
      guard let cell = findCell(named: name) else { break }
      // On iPad, sidebar cells may have empty visible frame — use coordinate-based swipe
      let start = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
      let end = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
      start.press(forDuration: 0.1, thenDragTo: end)
      let deleteButton = app.buttons["Delete"]
      if deleteButton.waitForExistence(timeout: 2) {
        deleteButton.tap()
        _ = deleteButton.waitForNonExistence(timeout: 2)
        // Wait for deletion animation to complete before retrying
        Thread.sleep(forTimeInterval: 1.0)
      }
    }
  }

  @MainActor
  func targetCell(named name: String) -> XCUIElement? {
    findCell(named: name)
  }

  @MainActor
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

  // MARK: - Queries

  @MainActor
  var targetCount: Int {
    app.cells.count
  }

  @MainActor
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
}

// swiftlint:enable prefer_nimble
