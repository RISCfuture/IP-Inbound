import CoreLocation
import XCTest

// swiftlint:disable final_test_case test_case_accessibility

class BaseTestCase: XCTestCase {

  // MARK: - Type Properties

  // ISO-8601 with fractional seconds — matches `UITestClock` parsing.
  @MainActor static let uiTestNowFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  // Default static fix: San Francisco, speed 0 → guidance stays in countdown mode.
  static let defaultFix = "37.7749,-122.4194,0,0,0"

  // MARK: - Instance Properties

  var app: XCUIApplication!

  @MainActor var isIPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
  }

  // MARK: - XCTestCase

  override func setUpWithError() throws {
    continueAfterFailure = false

    // Handle location permission alerts that appear during test interaction.
    // XCUITest's default handler taps "Don't Allow" which breaks tests.
    addUIInterruptionMonitor(withDescription: "Location Permission") { alert in
      MainActor.assumeIsolated {
        let allowButton = alert.buttons["Allow While Using App"]
        if allowButton.exists {
          allowButton.tap()
          return true
        }
        return false
      }
    }
  }

  // MARK: - Methods

  @MainActor
  func launchApp(
    now: Date? = nil,
    location: String? = defaultFix,
    path: String? = nil
  ) {
    let knownApps = ["codes.tim.FART"]
    for bundleID in knownApps {
      let other = XCUIApplication(bundleIdentifier: bundleID)
      if other.state != .notRunning { other.terminate() }
    }

    if UIDevice.current.userInterfaceIdiom == .pad {
      XCUIDevice.shared.orientation = .landscapeLeft
    }

    app = XCUIApplication()
    app.launchArguments.append("-UITests")
    if let now {
      app.launchEnvironment["UITEST_NOW"] = Self.uiTestNowFormatter.string(from: now)
    }
    if let path {
      app.launchEnvironment["UITEST_LOCATION_PATH"] = path
    } else if let location {
      app.launchEnvironment["UITEST_LOCATION"] = location
    }
    app.resetAuthorizationStatus(for: .location)
    app.launch()
    waitForAppStability()
    handleLocationPermissionIfNeeded()
  }

  @MainActor
  func setSimulatedLocation(latitude: Double, longitude: Double) {
    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: latitude, longitude: longitude)
    )
  }

  @MainActor
  func setSimulatedLocation(_ location: CLLocation) {
    XCUIDevice.shared.location = XCUILocation(location: location)
  }

  @MainActor
  func handleLocationPermissionIfNeeded() {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let allowButton = springboard.alerts.buttons["Allow While Using App"]
    if allowButton.waitForExistence(timeout: 2) {
      allowButton.tap()
    }
  }

  @MainActor
  func waitForAppStability(timeout: TimeInterval = 5) {
    _ = app.wait(for: .runningForeground, timeout: timeout)
  }

  func skipOniOS18() throws {
    if #unavailable(iOS 26) {
      throw XCTSkip("SwiftData view update bug on iOS 18.x - see Apple Forums thread 757866")
    }
  }
}

// swiftlint:enable final_test_case test_case_accessibility
