import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

struct TOTSetupPage: Page {
  let app: XCUIApplication

  var isDisplayed: Bool {
    app.segmentedControls["timeDisplayModePicker"].waitForExistence(timeout: 3)
  }

  // MARK: - Elements

  var timeDisplayModePicker: XCUIElement {
    app.segmentedControls["timeDisplayModePicker"]
  }
  var timeEntryField: XCUIElement {
    // The time entry field is a Text with .isButton trait, so it appears as a button in XCUITest
    let button = app.buttons["timeEntryField"]
    if button.exists { return button }
    let text = app.staticTexts["timeEntryField"]
    if text.exists { return text }
    // Fallback to other elements
    return app.otherElements["timeEntryField"]
  }
  var defineIPButton: XCUIElement { app.buttons["defineIPButton"] }
  var flyButton: XCUIElement { app.buttons["flyButton"] }

  // MARK: - Actions

  func selectLocalTime() {
    let picker = scrollToVisible(timeDisplayModePicker) ?? timeDisplayModePicker
    XCTAssertTrue(picker.waitForExistence(timeout: 3))
    picker.buttons["Target Local"].forceTap()
  }

  func selectZuluTime() {
    let picker = scrollToVisible(timeDisplayModePicker) ?? timeDisplayModePicker
    XCTAssertTrue(picker.waitForExistence(timeout: 3))
    picker.buttons["Zulu"].forceTap()
  }

  func enterTime(_ time: String) {
    enterOnKeypad(time)
  }

  @discardableResult
  func tapFly() async -> FlyPage {
    await tapButton("flyButton", toReveal: app.otherElements["flyView"])
    return FlyPage(app: app)
  }

  @discardableResult
  func tapBackToIPSetup() async -> IPSetupPage {
    await tapButton("defineIPButton", toReveal: app.buttons["timeOnTargetButton"])
    return IPSetupPage(app: app)
  }

  // MARK: - Queries

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

  func timeEntryFieldLabel() -> String {
    XCTAssertTrue(timeEntryField.waitForExistence(timeout: 3))
    return timeEntryField.label
  }
}

// swiftlint:enable prefer_nimble
