import XCTest

// No-op placeholder for navigation timing - rely on waitForExistence instead
func waitForNavigation() {
  // Intentionally empty - navigation timing is handled by waitForExistence calls
}

extension XCUIElement {
  var isVisible: Bool {
    // Use firstMatch to avoid "Multiple matching elements" on iPad split views
    let resolved = firstMatch
    guard resolved.exists, !resolved.frame.isEmpty else { return false }
    // Frame-based check: visible if the element's frame is within the window.
    // Liquid Glass makes nav bars translucent and floating, so elements behind
    // the nav bar report isHittable == false despite being on-screen.
    let app = XCUIApplication()
    guard let firstWindow = app.windows.allElementsBoundByIndex.first else { return false }
    return firstWindow.frame.contains(resolved.frame)
  }

  func makeVisible(element: XCUIElement) -> XCUIElement? {
    if self.elementType == .scrollView || self.elementType == .collectionView
      || self.elementType == .table
    {
      let visible = self.scroll(to: element) || self.swipe(to: element)
      return visible ? element : nil
    }
    return self.swipe(to: element) ? element : nil
  }

  // Use the collection view's scrollToItem method via coordinate-based scrolling
  private func scroll(to element: XCUIElement) -> Bool {
    var attempts = 0

    while !element.isVisible && attempts < 10 {
      let startCoordinate = self.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
      let endCoordinate = self.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
      startCoordinate.press(forDuration: 0.01, thenDragTo: endCoordinate)
      attempts += 1
    }

    return element.isVisible
  }

  // Fallback to swipe-based scrolling with limits
  private func swipe(to element: XCUIElement) -> Bool {
    var attempts = 0

    while !element.isVisible && attempts < 10 {
      swipeUp()
      attempts += 1
    }

    return element.isVisible
  }
}

extension XCUIApplication {
  func scrollToTop() {
    let springboardApp = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    for bar in springboardApp.statusBars.allElementsBoundByIndex { bar.tap() }
  }
}
