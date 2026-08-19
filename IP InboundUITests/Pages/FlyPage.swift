import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

struct FlyPage: Page {
  let app: XCUIApplication

  var isDisplayed: Bool {
    // Displayed if the flyView, CDI, or countdown element exists. On iPad the
    // `flyView` identifier propagates onto a descendant button ("Recenter map"),
    // so match across any element type.
    anyElement(identifier: "flyView").waitForExistence(timeout: 5)
      || cdi.waitForExistence(timeout: 2)
      || countdown.waitForExistence(timeout: 2)
  }

  // The guidance content sets `.accessibilityIdentifier("cdi")`, but the ancestor `flyView` identifier
  // propagates onto its descendants and overrides it, so the element is found by its label.
  var cdi: XCUIElement { anyElement(label: "Course deviation indicator") }
  var countdown: XCUIElement { anyElement(identifier: "countdown") }
  var simulatorBanner: XCUIElement { app.staticTexts["simulatorBanner"] }
  var flySpeedDisplay: XCUIElement { app.staticTexts["flySpeedDisplay"] }
  // The required ground speed is appended to the tappable speed display as a "(… req.)" callout,
  // so it shares the `flySpeedDisplay` element — which carries the `.isButton` trait for
  // unit-cycling and is therefore exposed as a button, not a static text. Find it by its visible
  // "req." copy.
  var requiredSpeedDisplay: XCUIElement {
    let predicate = NSPredicate(format: "label CONTAINS[c] %@", "req.")
    return app.buttons.matching(predicate).firstMatch
  }
  // The distance readout carries the `.isButton` trait (for unit cycling) and the ancestor
  // `flyView` identifier propagates over its own, so it is found as a button by its distance label
  // (e.g. "9.8 nmi"), which cycles through nmi / mi / km on tap.
  var flyDistanceDisplay: XCUIElement {
    let predicate = NSPredicate(format: "label MATCHES %@", ".*[0-9].*(nmi|mi|km)")
    return app.buttons.matching(predicate).firstMatch
  }
  // The TOT readout carries the `.isButton` trait (for the local/zulu toggle) and the ancestor
  // `flyView` identifier propagates over its own, so it is found as a button by its time label —
  // either the zulu form ("1757Z") or the local one ("10:57 AM").
  var flyTOTDisplay: XCUIElement {
    let predicate = NSPredicate(format: "label MATCHES %@", "[0-9]{4}Z|[0-9]{1,2}:[0-9]{2}.*")
    return app.buttons.matching(predicate).firstMatch
  }

  var guidanceMode: String? {
    if anyElement(label: "P.POS → IP").exists { return "P.POS → IP" }
    if anyElement(label: "IP → Target").exists { return "IP → Target" }
    if anyElement(label: "P.POS → Target").exists { return "P.POS → Target" }
    return nil
  }

  var hasCDI: Bool { cdi.exists }
  var hasCountdown: Bool { countdown.exists }
  var hasSimulatorBanner: Bool { simulatorBanner.exists }

  // MARK: - Methods

  func tapSpeedToCycleUnits() {
    let speed = flySpeedDisplay
    if speed.waitForExistence(timeout: 3) {
      speed.forceTap()
    } else {
      // Fallback: tap distance display which also cycles units
      let distance = flyDistanceDisplay
      XCTAssertTrue(distance.waitForExistence(timeout: 3), "Distance display should exist")
      distance.forceTap()
    }
  }

  func tapTOTToToggleTimeMode() {
    XCTAssertTrue(flyTOTDisplay.waitForExistence(timeout: 3), "TOT display should exist")
    flyTOTDisplay.forceTap()
  }

  // On iPad the `flyView` accessibility identifier propagates onto its
  // descendants, so the Fly screen's content surfaces with identifier "flyView"
  // and the real text in the label. Match by identifier or label across any
  // element type so the same queries resolve on both iPhone and iPad.
  private func anyElement(identifier: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  private func anyElement(label: String) -> XCUIElement {
    app.descendants(matching: .any)
      .matching(NSPredicate(format: "label == %@", label))
      .firstMatch
  }

  func hasTargetName(_ name: String) -> Bool {
    anyElement(label: name).waitForExistence(timeout: 5)
  }

  func hasText(_ text: String) -> Bool {
    anyElement(label: text).waitForExistence(timeout: 5)
  }

  func hasTextContaining(_ text: String) -> Bool {
    let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
    return app.staticTexts.element(matching: predicate).waitForExistence(timeout: 5)
  }
}

// swiftlint:enable prefer_nimble
