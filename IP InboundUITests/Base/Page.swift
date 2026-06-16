import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

protocol Page {
  var app: XCUIApplication { get }
  @MainActor var isDisplayed: Bool { get }
}

extension Page {
  @MainActor
  @discardableResult
  func scrollToVisible(_ element: XCUIElement) -> XCUIElement? {
    // If element already exists and is hittable, no scrolling needed
    if element.exists && element.isHittable { return element }
    // Wait briefly for element to appear (covers layout/animation delays)
    if element.waitForExistence(timeout: 5) && element.isHittable { return element }
    // Scroll the detail collection view to find the element
    // On iPad, multiple collection views may exist (sidebar + detail);
    // iterate to find the one that can make the element visible.
    for i in 0..<app.collectionViews.count {
      let cv = app.collectionViews.element(boundBy: i)
      guard cv.exists else { continue }
      if let result = cv.makeVisible(element: element), result.exists {
        ensureHittable(result)
        return result
      }
    }
    // Element might be visible but behind nav bar — try ensureHittable
    if element.exists {
      ensureHittable(element)
      if element.isHittable { return element }
    }
    return nil
  }

  /// Tap the button identified by `identifier` and confirm `expected` appears,
  /// retrying a few times. On the iPad split view a `NavigationLink` push in the
  /// detail column can need more than one attempt, the live button can be a
  /// later (non-stale) match, and it may sit below the fold — so each attempt
  /// re-resolves a hittable match and scrolls it into view before tapping.
  ///
  /// This is XCUITestKit's `Retry.untilVerified` (the action-and-confirm
  /// pattern) with the IP-Inbound-specific live-match re-resolution and
  /// scroll-into-view kept inside the action closure.
  @MainActor
  @discardableResult
  func tapButton(
    _ identifier: String,
    toReveal expected: XCUIElement,
    attempts: UInt = 3
  ) -> Bool {
    Retry.untilVerified(
      maxAttempts: attempts,
      interval: 0,
      action: {
        let matches = app.buttons.matching(identifier: identifier)
        var target = matches.firstMatch
        for index in 0..<matches.count {
          let candidate = matches.element(boundBy: index)
          if candidate.exists, candidate.isHittable {
            target = candidate
            break
          }
        }
        (scrollToVisible(target) ?? target).forceTap()
      },
      until: { expected.waitForExistence(timeout: 5) }
    )
  }

  @MainActor
  func ensureHittable(_ element: XCUIElement) {
    guard element.exists, !element.isHittable else { return }
    for i in 0..<app.collectionViews.count {
      let cv = app.collectionViews.element(boundBy: i)
      guard cv.exists else { continue }
      let windowHeight = app.windows.firstMatch.frame.height
      for _ in 0..<3 {
        if element.frame.minY < windowHeight * 0.35 {
          let start = cv.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
          let end = cv.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
          start.press(forDuration: 0.01, thenDragTo: end)
        } else if element.frame.maxY > windowHeight * 0.75 {
          let start = cv.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
          let end = cv.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
          start.press(forDuration: 0.01, thenDragTo: end)
        } else {
          break
        }
        if element.isHittable || !element.exists { return }
      }
    }
  }

  @MainActor
  func enterOnKeypad(_ input: String) {
    for char in input {
      guard char.isNumber || char.isLetter else { continue }
      let button = app.buttons["keypad-\(char)"]
      XCTAssertTrue(button.waitForExistence(timeout: 8), "Keypad button '\(char)' should exist")
      if !button.waitUntilHittable(timeout: 8) {
        ensureHittable(button)
      }
      button.forceTap()
    }
  }

  @MainActor
  func tapDirection(_ direction: String) {
    let button = app.buttons["keypad-\(direction)"]
    XCTAssertTrue(button.waitForExistence(timeout: 3), "\(direction) button should exist")
    if !button.waitUntilHittable() {
      ensureHittable(button)
    }
    // Tapping a direction swaps the keypad to numeric, so the key becomes
    // non-hittable. A single forceTap is intermittently dropped on iPad,
    // leaving the keypad on the direction page; retry the tap until it switches.
    let switched = button.tap(until: {
      button.waitFor(NSPredicate(format: "isHittable == false"), timeout: ScaledTimeouts.short)
    })
    XCTAssertTrue(switched, "\(direction) button should disappear after tap")
    // Wait for numeric keypad to be ready
    let numericButton = app.buttons["keypad-1"]
    XCTAssertTrue(numericButton.waitForExistence(timeout: 2), "Numeric keypad should appear")
    numericButton.waitUntilHittable()
  }

  @MainActor
  func tapBackButton() {
    let backButton = app.navigationBars.buttons.element(boundBy: 0)
    backButton.forceTap()
  }

  @MainActor
  func captureScreenshot(name: String, test: XCTestCase) {
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = name
    screenshot.lifetime = .keepAlways
    test.add(screenshot)
  }
}

// swiftlint:enable prefer_nimble
