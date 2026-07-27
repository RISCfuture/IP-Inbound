import XCTest
import XCUITestKit

struct TutorialPage: Page {
  let app: XCUIApplication

  var isDisplayed: Bool {
    app.staticTexts["How to Use IP Inbound"].waitForExistence(timeout: 5)
  }

  var tutorialTitle: XCUIElement { app.staticTexts["How to Use IP Inbound"] }
  var doneButton: XCUIElement { app.buttons["Done"] }
  var closeButton: XCUIElement { app.buttons["Close"] }

  // MARK: - Methods

  func scrollDown() {
    app.swipeUp()
  }

  @discardableResult
  func dismiss() -> TargetListPage {
    if doneButton.exists {
      doneButton.forceTap()
    } else if closeButton.exists {
      closeButton.forceTap()
    } else {
      app.swipeDown()
    }
    return TargetListPage(app: app)
  }

  @discardableResult
  func dismissViaSwipeDown() -> TargetListPage {
    app.swipeDown()
    return TargetListPage(app: app)
  }

  func hasSectionTitle(_ title: String) -> Bool {
    let text = app.staticTexts[title]
    // Wait briefly for initial render (LazyVStack may need a moment)
    if text.waitForExistence(timeout: 2) { return true }
    // Scroll until we find it or exhaust attempts. After each swipe, give the
    // newly laid-out content a short auto-waiting probe rather than a fixed
    // settle: `waitForExistence` returns as soon as the title renders.
    for _ in 0..<10 {
      app.swipeUp()
      if text.waitForExistence(timeout: 0.5) { return true }
    }
    return false
  }
}
