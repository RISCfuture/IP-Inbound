import CoreLocation
import XCTest
import XCUITestKit

// swiftlint:disable final_test_case test_case_accessibility

class BaseTestCase: XCTestCase {

  // MARK: - Type Properties

  // ISO-8601 with fractional seconds — matches `UITestClock` parsing.
  static let uiTestNowFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  // Default static fix: San Francisco, speed 0 → guidance stays in countdown mode.
  static let defaultFix = "37.7749,-122.4194,0,0,0"

  // MARK: - Instance Properties

  var app: XCUIApplication!

  var isIPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
  }

  // MARK: - XCTestCase

  override func setUp() async throws {
    continueAfterFailure = false

    // Handle location permission alerts that appear during test interaction.
    // XCUITest's default handler taps "Don't Allow" which breaks tests, so
    // register a monitor that grants the prompt (taps "Allow While Using App").
    addSystemAlertMonitor(
      description: "Location Permission",
      buttonLabels: ["Allow While Using App"]
    )
  }

  // MARK: - Methods

  func launchApp(
    now: Date? = nil,
    location: String? = defaultFix,
    path: String? = nil
  ) async {
    let knownApps = ["codes.tim.FART"]
    for bundleID in knownApps {
      let other = XCUIApplication(bundleIdentifier: bundleID)
      if other.state != .notRunning { other.terminate() }
    }

    if UIDevice.current.userInterfaceIdiom == .pad {
      XCUIDevice.shared.orientation = .landscapeLeft
    }

    app = XCUIApplication()
    app.disableLogStderrMirroring()
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
    await handleLocationPermissionIfNeeded()
  }

  func setSimulatedLocation(latitude: Double, longitude: Double) {
    XCUIDevice.shared.location = XCUILocation(
      location: CLLocation(latitude: latitude, longitude: longitude)
    )
  }

  func setSimulatedLocation(_ location: CLLocation) {
    XCUIDevice.shared.location = XCUILocation(location: location)
  }

  func handleLocationPermissionIfNeeded() async {
    // Tap the location prompt's "Allow While Using App" on SpringBoard directly,
    // at this known point in the flow, without depending on a follow-up
    // interaction (unlike `addUIInterruptionMonitor`). Safe to call defensively:
    // returns without failing if no prompt is present.
    await SystemAlert.dismiss(labels: ["Allow While Using App"])
  }

  func waitForAppStability(timeout: TimeInterval = 5) {
    _ = app.wait(for: .runningForeground, timeout: timeout)
  }
}

// swiftlint:enable final_test_case test_case_accessibility
