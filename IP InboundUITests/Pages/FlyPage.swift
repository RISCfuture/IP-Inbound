import XCTest

// swiftlint:disable prefer_nimble

struct FlyPage: Page {
  let app: XCUIApplication

  @MainActor var isDisplayed: Bool {
    // Displayed if the flyView, CDI, or countdown element exists.
    app.otherElements["flyView"].waitForExistence(timeout: 5)
      || app.otherElements["cdi"].waitForExistence(timeout: 2)
      || app.otherElements["countdown"].waitForExistence(timeout: 2)
  }

  // The guidance content sets `.accessibilityIdentifier("cdi")`, but the ancestor `flyView` identifier
  // propagates onto its descendants and overrides it, so the element is found by its label.
  @MainActor var cdi: XCUIElement {
    app.otherElements.matching(NSPredicate(format: "label == %@", "Course deviation indicator"))
      .firstMatch
  }
  @MainActor var countdown: XCUIElement { app.otherElements["countdown"] }
  @MainActor var simulatorBanner: XCUIElement { app.staticTexts["simulatorBanner"] }
  @MainActor var flySpeedDisplay: XCUIElement { app.staticTexts["flySpeedDisplay"] }
  // The required ground speed is appended to the tappable speed display as a "(… req.)" callout,
  // so it shares the `flySpeedDisplay` element — which carries the `.isButton` trait for
  // unit-cycling and is therefore exposed as a button, not a static text. Find it by its visible
  // "req." copy.
  @MainActor var requiredSpeedDisplay: XCUIElement {
    let predicate = NSPredicate(format: "label CONTAINS[c] %@", "req.")
    return app.buttons.matching(predicate).firstMatch
  }
  // The distance readout carries the `.isButton` trait (for unit cycling) and the ancestor
  // `flyView` identifier propagates over its own, so it is found as a button by its distance label
  // (e.g. "9.8 nmi"), which cycles through nmi / mi / km on tap.
  @MainActor var flyDistanceDisplay: XCUIElement {
    let predicate = NSPredicate(format: "label MATCHES %@", ".*[0-9].*(nmi|mi|km)")
    return app.buttons.matching(predicate).firstMatch
  }
  @MainActor var flyTOTDisplay: XCUIElement { app.staticTexts["flyTOTDisplay"] }

  @MainActor var guidanceMode: String? {
    if app.staticTexts["P.POS → IP"].exists { return "P.POS → IP" }
    if app.staticTexts["IP → Target"].exists { return "IP → Target" }
    if app.staticTexts["P.POS → Target"].exists { return "P.POS → Target" }
    return nil
  }

  @MainActor var hasCDI: Bool { cdi.exists }
  @MainActor var hasCountdown: Bool { countdown.exists }
  @MainActor var hasSimulatorBanner: Bool { simulatorBanner.exists }

  // MARK: - Methods

  @MainActor
  func tapSpeedToCycleUnits() {
    let speed = flySpeedDisplay
    if speed.waitForExistence(timeout: 3) {
      forceTap(speed)
    } else {
      // Fallback: tap distance display which also cycles units
      let distance = flyDistanceDisplay
      XCTAssertTrue(distance.waitForExistence(timeout: 3), "Distance display should exist")
      forceTap(distance)
    }
  }

  @MainActor
  func tapTOTToToggleTimeMode() {
    XCTAssertTrue(flyTOTDisplay.waitForExistence(timeout: 3), "TOT display should exist")
    forceTap(flyTOTDisplay)
  }

  @MainActor
  func hasTargetName(_ name: String) -> Bool {
    app.staticTexts[name].waitForExistence(timeout: 5)
  }

  @MainActor
  func hasText(_ text: String) -> Bool {
    app.staticTexts[text].waitForExistence(timeout: 5)
  }

  @MainActor
  func hasTextContaining(_ text: String) -> Bool {
    let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
    return app.staticTexts.element(matching: predicate).waitForExistence(timeout: 5)
  }
}

// swiftlint:enable prefer_nimble
