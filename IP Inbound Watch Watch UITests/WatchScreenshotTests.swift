import XCTest

/// Captures the watch app's marketing screens for the App Store. Each test launches one
/// deterministic state through `WatchAppScreen` and saves the screen as a result-bundle attachment;
/// the `watch_screenshots` fastlane lane exports them. watchOS renders dark-only, so there is a
/// single set rather than the iPhone's light/dark split.
final class WatchScreenshotTests: XCTestCase {
  override func setUp() {
    continueAfterFailure = false
  }

  @MainActor
  func testScreenshot_cdi() {
    let screen = WatchAppScreen().launchAirborne(offsetEastNM: 2)
    screen.assertCDIVisible()
    screen.screenshot("1-cdi")
  }

  @MainActor
  func testScreenshot_countdown() {
    let screen = WatchAppScreen().launchOnGround()
    screen.assertCountdownVisible()
    screen.screenshot("2-countdown")
  }

  @MainActor
  func testScreenshot_placeholder() {
    let screen = WatchAppScreen().launchWithoutTarget()
    screen.assertPlaceholderVisible()
    screen.screenshot("3-placeholder")
  }
}
