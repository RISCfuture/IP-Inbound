import XCTest

// swiftlint:disable prefer_nimble

protocol Page {
  var app: XCUIApplication { get }
  @MainActor var isDisplayed: Bool { get }
}

extension Page {
  @MainActor
  @discardableResult
  func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
    element.waitForExistence(timeout: timeout)
  }

  @MainActor
  @discardableResult
  func waitForHittable(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
    let predicate = NSPredicate(format: "isHittable == true")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
    return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
  }

  @MainActor
  @discardableResult
  func scrollToVisible(_ element: XCUIElement) -> XCUIElement? {
    // If element already exists and is hittable, no scrolling needed
    if element.exists && element.isHittable { return element }
    // Wait briefly for element to appear (covers layout/animation delays)
    if element.waitForExistence(timeout: 2) && element.isHittable { return element }
    // Scroll the detail collection view to find the element
    // On iPad, multiple collection views may exist (sidebar + detail);
    // iterate to find the one that can make the element visible.
    for i in 0..<app.collectionViews.count {
      let cv = app.collectionViews.element(boundBy: i)
      guard cv.exists else { continue }
      if let result = cv.makeVisible(element: element), result.exists { return result }
    }
    return nil
  }

  @MainActor
  func clearAndType(in textField: XCUIElement, text: String) {
    // Ensure element is hittable before attempting to type
    let predicate = NSPredicate(format: "isHittable == true")
    let expectation = XCTNSPredicateExpectation(predicate: predicate, object: textField)
    _ = XCTWaiter.wait(for: [expectation], timeout: 3)
    textField.tap()
    textField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
    textField.typeText(text)
  }

  @MainActor
  func enterOnKeypad(_ input: String) {
    for char in input {
      guard char.isNumber || char.isLetter else { continue }
      let button = app.buttons["keypad-\(char)"]
      XCTAssertTrue(button.waitForExistence(timeout: 4), "Keypad button '\(char)' should exist")
      let predicate = NSPredicate(format: "isHittable == true")
      let expectation = XCTNSPredicateExpectation(predicate: predicate, object: button)
      XCTAssertEqual(
        XCTWaiter.wait(for: [expectation], timeout: 4),
        .completed,
        "Keypad button '\(char)' should be hittable"
      )
      button.tap()
    }
  }

  @MainActor
  func tapDirection(_ direction: String) {
    let button = app.buttons["keypad-\(direction)"]
    XCTAssertTrue(button.waitForExistence(timeout: 3), "\(direction) button should exist")
    waitForHittable(button)
    button.tap()
    // Wait for direction button to disappear (keypad switches to numeric)
    let gone = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "isHittable == false"),
      object: button
    )
    XCTAssertEqual(
      XCTWaiter.wait(for: [gone], timeout: 3),
      .completed,
      "\(direction) button should disappear after tap"
    )
    // Wait for numeric keypad to be ready
    let numericButton = app.buttons["keypad-1"]
    XCTAssertTrue(numericButton.waitForExistence(timeout: 2), "Numeric keypad should appear")
    waitForHittable(numericButton)
  }

  @MainActor
  func tapBackButton() {
    app.navigationBars.buttons.element(boundBy: 0).tap()
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
