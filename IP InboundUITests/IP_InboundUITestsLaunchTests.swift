import CoreLocation
import XCTest

// swiftlint:disable prefer_nimble
// swiftlint:disable empty_count

final class IP_InboundUITestsLaunchTests: XCTestCase {
  override static var runsForEachTargetApplicationUIConfiguration: Bool {
    false  // Only run once, not for each configuration
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  // MARK: - Launch Tests
  // Note: Navigation and interaction tests have been moved to IP_InboundUITests.swift
  // This file should only contain tests related to app launch and screenshots

  // MARK: - Helper Methods
  // Note: Helper methods are now in IP_InboundUITests.swift to avoid duplication
}

// swiftlint:enable prefer_nimble
// swiftlint:enable empty_count
