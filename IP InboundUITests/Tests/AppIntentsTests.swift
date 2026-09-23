import AppIntentsTesting
import XCTest
import XCUITestKit

// swiftlint:disable prefer_nimble

/// Runs the app's intents the way Siri and Shortcuts do: out of process, against the installed app.
///
/// Kept out of the `UI Tests` plan, and so out of CI, in a plan of their own: the intents are
/// delivered by the system to the app by bundle identifier, which needs the test runner and the app
/// signed by the same team.
final class AppIntentsTests: BaseTestCase {

  // MARK: - Type Properties

  private static let definitions = IntentDefinitions(bundleIdentifier: "codes.tim.IP-Inbound")

  // Ahead of the seeded target's 18:00Z time on target, so its run is live when the Fly screen opens.
  private static let beforeSeededTOT = "2026-05-18T17:50:00.000Z"

  // MARK: - Helpers

  /// Launches the app holding the seeded "Flythrough" target, so an intent run while it is up is
  /// performed by this process and finds the target in its store.
  @MainActor
  private func launchWithSeededTarget() async {
    app = XCUIApplication()
    app.disableLogStderrMirroring()
    app.launchArguments.append("-UITests")
    app.launchEnvironment["UITEST_NOW"] = Self.beforeSeededTOT
    app.launchEnvironment["UITEST_LOCATION"] = Self.defaultFix
    app.launchEnvironment["UITEST_SEED_TARGET"] = "1"
    app.resetAuthorizationStatus(for: .location)
    app.launch()
    waitForAppStability()
    await handleLocationPermissionIfNeeded()
  }

  /// The seeded target as the app's entity query hands it to Siri.
  private func seededTarget() async throws -> AnyAppEntity {
    let matches = try await Self.definitions.entities["TargetEntity"].entities(
      matching: "Flythrough"
    )
    return try XCTUnwrap(matches.first, "The entity query should find the seeded target")
  }

  // MARK: - Tests

  @MainActor
  func testFlyTargetIntentOpensTheTargetsFlyScreen() async throws {
    await launchWithSeededTarget()
    let target = try await seededTarget()

    try await Self.definitions.intents["FlyTargetIntent"].makeIntent(target: target).run()

    XCTAssertTrue(FlyPage(app: app).isDisplayed, "Flying a target should open its Fly screen")
  }
}

// swiftlint:enable prefer_nimble
