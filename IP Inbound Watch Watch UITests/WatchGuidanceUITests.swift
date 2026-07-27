import XCTest

/// Drives the watch app for UI tests, seeding the flown target and GPS fix through the launch
/// environment so the guidance views render deterministically — without WatchConnectivity or live
/// location (and so without a permission prompt).
struct WatchAppScreen {
  let app = XCUIApplication()

  @discardableResult
  func launchWithoutTarget() -> Self {
    launch(seeding: [:])
  }

  @discardableResult
  func launchOnGround() -> Self {
    launch(seeding: guidanceSeed(speedKnots: 5))
  }

  @discardableResult
  func launchAirborne(offsetEastNM: Double = 0) -> Self {
    launch(seeding: guidanceSeed(speedKnots: 250, offsetEastNM: offsetEastNM))
  }

  func assertPlaceholderVisible(_ file: StaticString = #filePath, _ line: UInt = #line) {
    assertVisible("watchPlaceholder", file, line)
  }

  func assertCountdownVisible(_ file: StaticString = #filePath, _ line: UInt = #line) {
    assertVisible("watchCountdown", file, line)
  }

  func assertCDIVisible(_ file: StaticString = #filePath, _ line: UInt = #line) {
    assertVisible("watchCDI", file, line)
  }

  /// Captures the current watch screen as a named, always-kept attachment in the result bundle,
  /// where the `watch_screenshots` fastlane lane harvests it into the App Store screenshot set.
  func screenshot(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    XCTContext.runActivity(named: "Screenshot \(name)") { $0.add(attachment) }
  }

  private func guidanceSeed(speedKnots: Int, offsetEastNM: Double = 0) -> [String: String] {
    var seed = [
      "UITEST_WATCH_SEED_TARGET": "1",
      "UITEST_WATCH_TOT_OFFSET": "600",
      "UITEST_WATCH_SPEED_KTS": "\(speedKnots)"
    ]
    if offsetEastNM != 0 {
      seed["UITEST_WATCH_OFFSET_EAST_NM"] = "\(offsetEastNM)"
    }
    return seed
  }

  @discardableResult
  private func launch(seeding environment: [String: String]) -> Self {
    app.launchArguments.append("-UITests")
    for (key, value) in environment { app.launchEnvironment[key] = value }
    app.launch()
    return self
  }

  private func assertVisible(_ identifier: String, _ file: StaticString, _ line: UInt) {
    let element = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    // swiftlint:disable:next prefer_nimble
    XCTAssertTrue(
      element.waitForExistence(timeout: 10),
      "Expected “\(identifier)” to be visible",
      file: file,
      line: line
    )
  }
}

final class WatchGuidanceUITests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  func testPlaceholderShownWhenNoTargetIsFlown() {
    WatchAppScreen()
      .launchWithoutTarget()
      .assertPlaceholderVisible()
  }

  func testCountdownShownWhileOnGround() {
    WatchAppScreen()
      .launchOnGround()
      .assertCountdownVisible()
  }

  func testCDIShownWhenAirborne() {
    WatchAppScreen()
      .launchAirborne()
      .assertCDIVisible()
  }
}
