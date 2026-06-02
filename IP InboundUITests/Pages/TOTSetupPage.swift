import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

struct TOTSetupPage: Page {
  let app: XCUIApplication

  @MainActor var isDisplayed: Bool {
    app.segmentedControls["timeDisplayModePicker"].waitForExistence(timeout: 3)
  }

  // MARK: - Elements

  @MainActor var timeDisplayModePicker: XCUIElement {
    app.segmentedControls["timeDisplayModePicker"]
  }
  @MainActor var timeEntryField: XCUIElement {
    // The time entry field is a Text with .isButton trait, so it appears as a button in XCUITest
    let button = app.buttons["timeEntryField"]
    if button.exists { return button }
    let text = app.staticTexts["timeEntryField"]
    if text.exists { return text }
    // Fallback to other elements
    return app.otherElements["timeEntryField"]
  }
  @MainActor var defineIPButton: XCUIElement { app.buttons["defineIPButton"] }
  @MainActor var flyButton: XCUIElement { app.buttons["flyButton"] }

  // MARK: - Actions

  @MainActor
  func selectLocalTime() {
    let picker = scrollToVisible(timeDisplayModePicker) ?? timeDisplayModePicker
    XCTAssertTrue(picker.waitForExistence(timeout: 3))
    picker.buttons["Target Local"].forceTap()
  }

  @MainActor
  func selectZuluTime() {
    let picker = scrollToVisible(timeDisplayModePicker) ?? timeDisplayModePicker
    XCTAssertTrue(picker.waitForExistence(timeout: 3))
    picker.buttons["Zulu"].forceTap()
  }

  @MainActor
  func enterTime(_ time: String) {
    enterOnKeypad(time)
  }

  @MainActor
  @discardableResult
  func tapFly() -> FlyPage {
    // The `flyView` identifier resolves to an otherElement on iPhone but
    // propagates onto a descendant button ("Recenter map") on iPad, so match it
    // regardless of element type.
    tapButton(
      "flyButton",
      toReveal: app.descendants(matching: .any).matching(identifier: "flyView").firstMatch
    )
    return FlyPage(app: app)
  }

  @MainActor
  @discardableResult
  func tapBackToIPSetup() -> IPSetupPage {
    tapButton("defineIPButton", toReveal: app.buttons["timeOnTargetButton"])
    return IPSetupPage(app: app)
  }

  // MARK: - Queries

  @MainActor
  func secondaryTimeString() -> String {
    let secondary = app.staticTexts.element(
      matching: NSPredicate(format: "identifier == %@ OR label CONTAINS[c] ':'", "secondaryTime")
    )
    // Find the secondary time text below the main time entry
    // It contains timezone abbreviation or zulu indicator
    let allTexts = app.staticTexts.allElementsBoundByIndex
    for text in allTexts {
      let label = text.label
      if label.contains("Z") || label.contains("GMT") || label.contains("UTC")
        || label.contains("PST") || label.contains("PDT") || label.contains("EST")
        || label.contains("EDT") || label.contains("CST") || label.contains("CDT")
        || label.contains("MST") || label.contains("MDT")
      {
        return label
      }
    }
    return secondary.label
  }

  @MainActor
  func timeEntryFieldLabel() -> String {
    XCTAssertTrue(timeEntryField.waitForExistence(timeout: 3))
    return timeEntryField.label
  }
}

// swiftlint:enable prefer_nimble
