import CoreLocation
import XCTest

// swiftlint:disable prefer_nimble

class BaseTestCase: XCTestCase {
  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false

    // Handle location permission alerts that appear during test interaction.
    // XCUITest's default handler taps "Don't Allow" which breaks tests.
    addUIInterruptionMonitor(withDescription: "Location Permission") { alert in
      let allowButton = alert.buttons["Allow While Using App"]
      if allowButton.exists {
        allowButton.tap()
        return true
      }
      return false
    }
  }

  /// Call at the start of each test to set up the app. Must be called from @MainActor context.
  @MainActor
  func launchApp() {
    // Terminate other apps that may interfere with UI tests
    let knownApps = ["codes.tim.FART"]
    for bundleID in knownApps {
      let other = XCUIApplication(bundleIdentifier: bundleID)
      if other.state != .notRunning { other.terminate() }
    }

    // iPad: ensure landscape so NavigationSplitView shows sidebar persistently
    if UIDevice.current.userInterfaceIdiom == .pad {
      XCUIDevice.shared.orientation = .landscapeLeft
    }

    app = XCUIApplication()
    app.launchArguments.append("-UITests")
    app.resetAuthorizationStatus(for: .location)
    app.launch()
    waitForAppStability()
    setSimulatedLocation(latitude: 37.7749, longitude: -122.4194)
    handleLocationPermissionIfNeeded()
    // Re-set location after permission grant — iPad may miss the initial update
    setSimulatedLocation(latitude: 37.7749, longitude: -122.4194)
  }

  @MainActor
  var isIPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
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

// swiftlint:enable prefer_nimble
