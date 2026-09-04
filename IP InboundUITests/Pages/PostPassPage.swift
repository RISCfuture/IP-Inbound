import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

struct PostPassPage: Page {
  let app: XCUIApplication

  var isDisplayed: Bool {
    waitUntilDisplayed(timeout: 10)
  }

  /// The screen's own identifier, which its root applies to everything it draws. The headline is
  /// not used to locate it: that says which route the run took to get here — a pass flown, or a
  /// run that lapsed with the target still ahead — so matching on it would tie every caller to one
  /// of the two.
  private var container: XCUIElement {
    app.descendants(matching: .any).matching(identifier: "postPassView").firstMatch
  }

  /// The headline for a pass that was flown.
  var crossedTitle: XCUIElement { app.staticTexts["Past Target"] }

  /// The headline for a run that lapsed without the target ever being crossed.
  var lapsedTitle: XCUIElement { app.staticTexts["Past TOT"] }

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
    container.waitForExistence(timeout: timeout)
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
