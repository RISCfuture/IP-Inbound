import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

// The post-pass screen sets no identifiers of its own, so it is located by the text it shows.
struct PostPassPage: Page {
  let app: XCUIApplication

  var isDisplayed: Bool {
    waitUntilDisplayed(timeout: 10)
  }

  var titleText: XCUIElement { app.staticTexts["Past Target"] }

  // The “Fly <target>” button is labeled with the next target's name, which is not known here, so
  // it is matched by the part of the label that does not vary.
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
