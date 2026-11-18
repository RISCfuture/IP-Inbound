import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

struct FlyPage: Page {
  let app: XCUIApplication

  var isDisplayed: Bool {
    // Displayed if the flyView container, the CDI, or the countdown exists. Each surfaces as a
    // different element type, and the map-bearing iPad layout adds more, so match across any type.
    anyElement(identifier: "flyView").wait(timeout: 5)
      || cdi.wait(timeout: 2)
      || countdown.wait(timeout: 2)
  }

  var cdi: XCUIElement { anyElement(identifier: "cdi") }
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
  // Both readouts carry the `.isButton` trait for unit cycling and the local/zulu toggle, so they
  // surface as buttons rather than static texts.
  var flyDistanceDisplay: XCUIElement { app.buttons["flyDistanceDisplay"] }
  var flyTOTDisplay: XCUIElement { app.buttons["flyTOTDisplay"] }

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
    if speed.wait(timeout: 3) {
      speed.forceTap()
    } else {
      // Fallback: tap distance display which also cycles units
      let distance = flyDistanceDisplay
      XCTAssertTrue(distance.wait(timeout: 3), "Distance display should exist")
      distance.forceTap()
    }
  }

  func tapTOTToToggleTimeMode() {
    XCTAssertTrue(flyTOTDisplay.wait(timeout: 3), "TOT display should exist")
    flyTOTDisplay.forceTap()
  }

  // The Fly screen's elements surface as different types across layouts — a header is a static
  // text, a readout a button, the guidance content a container. Match across any element type so
  // the same queries resolve on both iPhone and iPad.
  private func anyElement(identifier: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  private func anyElement(label: String) -> XCUIElement {
    app.descendants(matching: .any)
      .matching(NSPredicate(format: "label == %@", label))
      .firstMatch
  }

  func hasTargetName(_ name: String) -> Bool {
    anyElement(label: name).wait(timeout: 5)
  }

  func hasText(_ text: String) -> Bool {
    anyElement(label: text).wait(timeout: 5)
  }

  func hasTextContaining(_ text: String) -> Bool {
    let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
    return app.staticTexts.element(matching: predicate).wait(timeout: 5)
  }
}

// swiftlint:enable prefer_nimble
