import CoreLocation
import XCTest
import XCUIPromoKit
import XCUITestKit

// swiftlint:disable prefer_nimble
/// Captures the stills `promo/storyboard.json` sets as App Store screenshots, and that
/// `import_screenshots` turns into the tutorial's illustrations.
/// `promokit stills` runs it; anywhere else, the test skips.
///
/// Each phase of a run is its own launch on the harness's pinned clock, with the aircraft placed
/// where that phase finds it.
nonisolated final class StoreScreenshots: XCTestCase {

  // MARK: - Type Properties

  /// `UITEST_LOCATION` rich-fix strings: `lat,lon,alt,courseTrue,speed`.
  private static let
    targetFix = "36.772367,-115.453840,1060,0,0",
    groundFix = "36.2362,-115.0342556,570,29,0",
    preIPFix = "36.853375,-115.593249,1502,179,62",
    postIPFix = "36.80782,-115.484047,1502,179,62"

  /// `UITEST_LOCATION_PATH` run-in that leaves the IP at launch, crosses the
  /// target `runInSeconds` later at about 120 kn, and carries on past it.
  /// Launching that long before TOT puts the crossing on the TOT, with time to
  /// spare for the harness to reach the Fly screen first.
  private static let runInSeconds = 77
  private static let runInTrack = """
    [{"t":0,"lat":36.807822,"lon":-115.484047,"crs":179,"spd":62},
     {"t":77,"lat":36.772367,"lon":-115.453840,"crs":179,"spd":62},
     {"t":90,"lat":36.766381,"lon":-115.448740,"crs":179,"spd":62}]
    """

  // MARK: - XCTestCase

  override func setUpWithError() throws {
    try super.setUpWithError()
    continueAfterFailure = false
  }

  // MARK: - Tests

  @MainActor
  func testCaptureStills() throws {
    try XCTSkipUnless(
      ProcessInfo.processInfo.environment[PromoStill.directoryVariable] != nil,
      "Only `promokit stills` captures the App Store stills."
    )
    try captureSetup()
    try captureFlyView(.ground, now: UITestHarness.iso(offsetMinutes: -30), fix: Self.groundFix)
    try captureFlyView(
      .pushCountdown,
      now: UITestHarness.iso(offsetMinutes: -15),
      fix: Self.preIPFix
    )
    try captureFlyView(
      .speedGuidance,
      now: UITestHarness.iso(offsetMinutes: -7),
      fix: Self.preIPFix
    )
    try captureFlyView(.contingency, now: UITestHarness.iso(offsetMinutes: -3), fix: Self.preIPFix)
    try captureFlyView(.runIn, now: UITestHarness.iso(offsetMinutes: -2), fix: Self.postIPFix)
    try capturePastTarget()
  }

  // MARK: - Phases

  /// Walks the setup pages: adds a target at the aircraft's position, places its IP and keys in
  /// the TOT. No target is seeded, so the target list starts empty.
  @MainActor
  private func captureSetup() throws {
    let app = launch(now: nil, position: .fix(Self.targetFix), seedTarget: false)
    try makeTarget(app: app)
    setTimeEntry(app: app, minutesFromNow: 30)
    try capture(.tot)
    app.terminate()
  }

  /// Captures the seeded target's Fly screen with the clock and the aircraft where `shot` finds
  /// them.
  @MainActor
  private func captureFlyView(_ shot: Shot, now: String, fix: String) throws {
    let app = launch(now: now, position: .fix(fix))
    UITestHarness.openFlyView(in: app)
    Thread.sleep(forTimeInterval: 3.0)
    try capture(shot)
    app.terminate()
  }

  /// Flies the run-in track across the target on the TOT, then captures the pass report.
  @MainActor
  private func capturePastTarget() throws {
    let app = launch(
      now: UITestHarness.iso(offsetSeconds: -Self.runInSeconds),
      position: .track(Self.runInTrack),
      seedNextTarget: true
    )
    UITestHarness.openFlyView(in: app)
    XCTAssertTrue(
      app.staticTexts["Past Target"]
        .waitForExistence(timeout: TimeInterval(Self.runInSeconds) + 30),
      "Post-pass view should appear once past target + past TOT"
    )
    Thread.sleep(forTimeInterval: 1.0)
    try capture(.pastTarget)
    app.terminate()
  }

  // MARK: - Methods

  @MainActor
  private func launch(
    now: String?,
    position: UITestHarness.Position,
    seedTarget: Bool = true,
    seedNextTarget: Bool = false
  ) -> XCUIApplication {
    let app = XCUIApplication()
    UITestHarness.launch(
      app,
      now: now,
      position: position,
      seedTarget: seedTarget,
      seedNextTarget: seedNextTarget
    )
    return app
  }

  @MainActor
  private func capture(_ shot: Shot) throws {
    try PromoStill.capture(shot.rawValue, in: self)
  }

  @MainActor
  private func makeTarget(app: XCUIApplication) throws {
    // `UITEST_LOCATION` (set by the harness) is the target's intended
    // coordinate, so `NewTargetButton.resolvedCoordinate` captures it here.
    app.buttons["addTargetButton"].tap()

    let targetNameField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["targetNameField"]
    )!
    clearAndTypeText(in: targetNameField, text: UITestHarness.seedTargetName)

    Thread.sleep(forTimeInterval: 0.5)
    try capture(.defineTarget)

    app.buttons["defineIPButton"].tap()

    let offsetBearingField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetBearingField"]
    )!
    XCTAssertTrue(
      offsetBearingField.waitForExistence(timeout: 2),
      "Offset bearing field should exist"
    )
    clearAndTypeText(in: offsetBearingField, text: "\(Int(LocationHelper.IPBearingTrue))")

    app.buttons["offsetBearingTrue"].tap()

    let offsetDistanceField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["offsetDistanceField"]
    )!
    clearAndTypeText(in: offsetDistanceField, text: "\(LocationHelper.IPDistanceNM)")

    if let groundSpeedField = app.collectionViews.firstMatch.makeVisible(
      element: app.textFields["groundSpeedField"]
    ) {
      clearAndTypeText(in: groundSpeedField, text: "\(LocationHelper.targetGroundSpeed)")
    }

    Thread.sleep(forTimeInterval: 0.5)
    try capture(.defineIP)

    app.buttons["timeOnTargetButton"].tap()
  }

  @MainActor
  private func setTimeEntry(app: XCUIApplication, minutesFromNow: Double) {
    XCTAssertTrue(
      app.segmentedControls["timeDisplayModePicker"]
        .waitForExistence(timeout: 2),
      "Time mode picker should appear"
    )

    app.segmentedControls["timeDisplayModePicker"].buttons["Target Local"].tap()

    let targetTime = Date().addingTimeInterval(minutesFromNow * 60)
    let components = Calendar.current.dateComponents([.hour, .minute], from: targetTime)

    // The keypad consumes bare digits, so build HHMMSS from the components rather than through a
    // locale-dependent formatter. Seconds are always zeroed.
    let digits = String(format: "%02d%02d00", components.hour ?? 0, components.minute ?? 0)
    enterDigits(app: app, digits: digits)

    Thread.sleep(forTimeInterval: 1)
  }

  @MainActor
  private func clearAndTypeText(in textField: XCUIElement, text: String) {
    textField.tap()
    Thread.sleep(forTimeInterval: 0.2)
    textField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
    Thread.sleep(forTimeInterval: 0.1)
    textField.typeText(text + "\n")
  }

  @MainActor
  private func enterDigits(app: XCUIApplication, digits: String) {
    for digit in digits where digit.isNumber || digit.isLetter {
      app.buttons["keypad-\(digit)"].tap()
      Thread.sleep(forTimeInterval: 0.1)
    }
  }

  // MARK: - Nested Types

  /// The stills `promo/storyboard.json` captions, which also sets their order in the listing.
  private enum Shot: String {
    case runIn = "run-in"
    case speedGuidance = "speed-guidance"
    case contingency
    case pastTarget = "past-target"
    case defineTarget = "define-target"
    case defineIP = "define-ip"
    case pushCountdown = "push-countdown"
    case ground
    case tot
  }
}
// swiftlint:enable prefer_nimble
