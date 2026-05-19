import XCTest

// swiftlint:disable prefer_nimble

/// SwiftUI propagates the enclosing `flyView` accessibility identifier to every
/// descendant, so the post-pass screen is located by its text content rather
/// than by element identifiers (mirroring `FlyPage`).
struct PostPassPage: Page {
  let app: XCUIApplication

  @MainActor var isDisplayed: Bool {
    waitUntilDisplayed(timeout: 10)
  }

  @MainActor var titleText: XCUIElement { app.staticTexts["Pass Complete"] }

  @MainActor var flyNextTargetButton: XCUIElement { app.buttons["Fly next target"] }
  @MainActor var chooseTargetButton: XCUIElement { app.buttons["Choose target"] }

  @MainActor var missText: XCUIElement {
    let predicate = NSPredicate(
      format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@",
      "early",
      "late"
    )
    return app.staticTexts.element(matching: predicate)
  }

  @MainActor var missLabel: String { missText.label }

  // MARK: - Methods

  @MainActor
  func waitUntilDisplayed(timeout: TimeInterval) -> Bool {
    titleText.waitForExistence(timeout: timeout)
  }

  @MainActor
  @discardableResult
  func tapFlyNextTarget() -> FlyPage {
    XCTAssertTrue(
      flyNextTargetButton.waitForExistence(timeout: 5),
      "Fly next target button should appear"
    )
    forceTap(flyNextTargetButton)
    return FlyPage(app: app)
  }

  @MainActor
  @discardableResult
  func tapChooseTarget() -> TargetListPage {
    XCTAssertTrue(
      chooseTargetButton.waitForExistence(timeout: 5),
      "Choose target button should appear"
    )
    forceTap(chooseTargetButton)
    return TargetListPage(app: app)
  }
}

// swiftlint:enable prefer_nimble
