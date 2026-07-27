import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

// SwiftUI propagates the enclosing `flyView` accessibility identifier to every
// descendant, so the post-pass screen is located by its text content rather
// than by element identifiers (mirroring `FlyPage`).
struct PostPassPage: Page {
  let app: XCUIApplication

  var isDisplayed: Bool {
    waitUntilDisplayed(timeout: 10)
  }

  var titleText: XCUIElement { app.staticTexts["Past Target"] }

  // The post-pass “Fly <target>” button is labeled with the next target's name, and SwiftUI
  // overrides descendant identifiers with the enclosing `flyView` id, so match it by its label
  // prefix rather than by identifier.
  var flyNextTargetButton: XCUIElement {
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Fly ")).firstMatch
  }
  var chooseTargetButton: XCUIElement { app.buttons["Choose next target"] }

  var missText: XCUIElement {
    let predicate = NSPredicate(
      format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@",
      "early",
      "late"
    )
    return app.staticTexts.element(matching: predicate)
  }

  var missLabel: String { missText.label }

  // MARK: - Methods

  func waitUntilDisplayed(timeout: TimeInterval) -> Bool {
    titleText.waitForExistence(timeout: timeout)
  }

  @discardableResult
  func tapFlyNextTarget() -> FlyPage {
    XCTAssertTrue(
      flyNextTargetButton.waitForExistence(timeout: 5),
      "Fly next target button should appear"
    )
    flyNextTargetButton.forceTap()
    return FlyPage(app: app)
  }

  @discardableResult
  func tapChooseTarget() -> TargetListPage {
    XCTAssertTrue(
      chooseTargetButton.waitForExistence(timeout: 5),
      "Choose target button should appear"
    )
    chooseTargetButton.forceTap()
    return TargetListPage(app: app)
  }
}

// swiftlint:enable prefer_nimble
