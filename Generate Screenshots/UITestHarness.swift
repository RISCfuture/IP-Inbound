import Foundation
import XCTest

// swiftlint:disable prefer_nimble
/// Launches the app under its UI-test harness: a pinned clock, a simulated aircraft and seeded
/// targets, for the screenshot and preview tests.
enum UITestHarness {

  // MARK: - Type Properties

  /// Anchor for the harness-pinned clock. The seeded target's `timeOnTarget`
  /// is this instant; each scenario picks `UITEST_NOW` relative to it.
  static let seedTOTISO = "2026-05-18T18:00:00.000Z"

  /// User-facing target name for the seeded primary target. Overrides the
  /// harness default ("Flythrough") with a realistic place name so the tutorial
  /// screenshots match the makeTarget walkthrough's "Dog Bone Lake".
  static let seedTargetName = "Dog Bone Lake"

  /// The bottom-bar buttons that walk a target's setup pages, in order, to the Fly screen.
  private static let setupSteps = ["defineIPButton", "timeOnTargetButton", "flyButton"]

  /// How long the setup pages get to reach the Fly screen.
  private static let flyViewTimeout: TimeInterval = 30

  /// How long a page push gets to settle before the bottom bar is read again.
  private static let stepSettle: TimeInterval = 1

  // MARK: - Type Methods

  /// `seedTOTISO` moved by `offsetSeconds`, for `UITEST_NOW`.
  static func iso(offsetSeconds: Int) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let base = formatter.date(from: seedTOTISO) else {
      preconditionFailure("Invalid seedTOTISO: \(seedTOTISO)")
    }
    return formatter.string(from: base.addingTimeInterval(TimeInterval(offsetSeconds)))
  }

  static func iso(offsetMinutes: Int) -> String {
    iso(offsetSeconds: offsetMinutes * 60)
  }

  /// Launches `app` under the harness: pinned `UITEST_NOW` (optional), the
  /// aircraft's `position`, and optionally one or two seeded configured
  /// targets. Handles the location-permission alert and the Apple Intelligence
  /// banner before returning.
  @MainActor
  static func launch(
    _ app: XCUIApplication,
    now: String?,
    position: Position,
    seedTarget: Bool = true,
    seedNextTarget: Bool = false
  ) {
    app.launchArguments.append("-UITests")
    if let now {
      app.launchEnvironment["UITEST_NOW"] = now
    }
    switch position {
      case .fix(let fix): app.launchEnvironment["UITEST_LOCATION"] = fix
      case .track(let track): app.launchEnvironment["UITEST_LOCATION_PATH"] = track
    }
    if seedTarget {
      app.launchEnvironment["UITEST_SEED_TARGET"] = "1"
      app.launchEnvironment["UITEST_SEED_TARGET_NAME"] = seedTargetName
    }
    if seedNextTarget { app.launchEnvironment["UITEST_SEED_NEXT_TARGET"] = "1" }
    app.launchEnvironment["UITEST_BYPASS_TOT_RESET"] = "1"
    // Opt back into MapKit rendering — the production UI-test default
    // (`MapPlaceholder`) keeps non-screenshot tests quiescent, but the
    // tutorial screenshots need the real satellite map.
    app.launchEnvironment["UITEST_RENDER_MAPS"] = "1"
    app.resetAuthorizationStatus(for: .location)
    app.launch()

    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    if springboard.alerts.buttons["Allow While Using App"].waitForExistence(timeout: 5) {
      springboard.alerts.buttons["Allow While Using App"].tap()
    }

    // wait for Apple Intelligence banner to self-dismiss
    _ = app.textFields["nonexistent"].waitForExistence(timeout: 10)
  }

  /// Taps the seeded target and drives any residual setup pages so `app` lands on FlyView (or the
  /// post-pass view once the run is over). Mirrors the fallback in `PostPassFlowTests` for
  /// SwiftUI's occasional setup-path restore.
  @MainActor
  static func openFlyView(in app: XCUIApplication) {
    let seededTarget = app.staticTexts[seedTargetName]
    XCTAssertTrue(seededTarget.waitForExistence(timeout: 10), "Seeded target should appear")
    seededTarget.tap()

    let deadline = Date.now.addingTimeInterval(flyViewTimeout)
    while !isOnFlyView(app), Date.now < deadline {
      furthestSettledStep(in: app)?.tap()
      Thread.sleep(forTimeInterval: stepSettle)
    }
    XCTAssertTrue(isOnFlyView(app), "The seeded target's Fly screen should open")
  }

  // MARK: - Private Type Methods

  @MainActor
  private static func isOnFlyView(_ app: XCUIApplication) -> Bool {
    app.descendants(matching: .any)["flyView"].exists || app.staticTexts["Past Target"].exists
  }

  /// The furthest setup step whose button sits wholly on screen. iPad's split view can hold a
  /// step's button in both columns, so each match is checked rather than the identifier alone.
  @MainActor
  private static func furthestSettledStep(in app: XCUIApplication) -> XCUIElement? {
    for step in setupSteps.reversed() {
      let matches = app.buttons.matching(identifier: step).allElementsBoundByIndex
      if let button = matches.first(where: { isSettled($0, in: app) }) { return button }
    }
    return nil
  }

  /// Whether `button` sits wholly on screen. Each setup page's bottom bar holds the button back to
  /// the previous step as well as the one on to the next, and the previous page's bar stays until
  /// a push settles, so the furthest step on screen is the one to tap. Bottom-bar buttons never
  /// report `isHittable`, so the button's frame is what's checked.
  @MainActor
  private static func isSettled(_ button: XCUIElement, in app: XCUIApplication) -> Bool {
    button.exists && !button.frame.isEmpty && app.frame.contains(button.frame)
  }

  // MARK: - Nested Types

  /// Where the harness puts the aircraft: one fix held for the whole launch, or
  /// a track replayed against the pinned clock.
  enum Position {
    case fix(String)
    case track(String)
  }
}
// swiftlint:enable prefer_nimble
