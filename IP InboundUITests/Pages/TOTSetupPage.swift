import XCTest

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
    XCTAssertTrue(timeDisplayModePicker.waitForExistence(timeout: 3))
    forceTap(timeDisplayModePicker.buttons["Target Local"])
  }

  @MainActor
  func selectZuluTime() {
    XCTAssertTrue(timeDisplayModePicker.waitForExistence(timeout: 3))
    forceTap(timeDisplayModePicker.buttons["Zulu"])
  }

  @MainActor
  func enterTime(_ time: String) {
    enterOnKeypad(time)
  }

  @MainActor
  @discardableResult
  func tapFly() -> FlyPage {
    XCTAssertTrue(flyButton.waitForExistence(timeout: 3), "Fly button should appear")
    forceTap(flyButton)
    return FlyPage(app: app)
  }

  @MainActor
  @discardableResult
  func tapBackToIPSetup() -> IPSetupPage {
    forceTap(defineIPButton)
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
