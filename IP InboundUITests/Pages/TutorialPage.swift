import XCTest

struct TutorialPage: Page {
  let app: XCUIApplication

  @MainActor var isDisplayed: Bool {
    app.staticTexts["How to Use IP Inbound"].waitForExistence(timeout: 5)
  }

  @MainActor var tutorialTitle: XCUIElement { app.staticTexts["How to Use IP Inbound"] }
  @MainActor var doneButton: XCUIElement { app.buttons["Done"] }
  @MainActor var closeButton: XCUIElement { app.buttons["Close"] }

  // MARK: - Methods

  @MainActor
  func scrollDown() {
    app.swipeUp()
  }

  @MainActor
  @discardableResult
  func dismiss() -> TargetListPage {
    if doneButton.exists {
      forceTap(doneButton)
    } else if closeButton.exists {
      forceTap(closeButton)
    } else {
      app.swipeDown()
    }
    return TargetListPage(app: app)
  }

  @MainActor
  @discardableResult
  func dismissViaSwipeDown() -> TargetListPage {
    app.swipeDown()
    return TargetListPage(app: app)
  }

  @MainActor
  func hasSectionTitle(_ title: String) -> Bool {
    let text = app.staticTexts[title]
    // Wait briefly for initial render (LazyVStack may need a moment)
    if text.waitForExistence(timeout: 2) { return true }
    // Scroll until we find it or exhaust attempts
    for _ in 0..<10 {
      app.swipeUp()
      Thread.sleep(forTimeInterval: 0.3)
      if text.exists { return true }
    }
    return false
  }
}
