import Foundation
import XCTest
import XCUIPromoKit
import XCUITestKit

// swiftlint:disable prefer_nimble
/// Plays the App Store preview's script while `promokit record flythrough` films the simulator.
///
/// The take briefs a target, then flies it: each phase of the flight is its own launch on the
/// harness's pinned clock, made off camera. The take keeps the stretches worth showing and files
/// each under the scene `promo/storyboard.json` frames. Outside `promokit record`, the test skips.
nonisolated final class PreviewRecording: XCTestCase {
  private static let tapLanding: TimeInterval = 0.3
  private static let pageSettle: TimeInterval = 1.0
  private static let keySettle: TimeInterval = 0.12
  private static let phaseHold: TimeInterval = 3.0
  private static let keystroke: TimeInterval = 0.07

  /// How long a cut stays off camera. Footage the take keeps on either side of one stays two
  /// stretches, so `promo/storyboard.json` can pace each on its own.
  private static let cutAway: TimeInterval = 0.5

  /// `UITEST_LOCATION`: the target's own coordinate, which a new target is created at.
  private static let targetFix = "36.772367,-115.453840,1060,0,0"
  /// `UITEST_LOCATION`: short of the IP on the 179° inbound course at 120 kn.
  private static let preIPFix = "36.853375,-115.593249,1502,179,62"

  /// The IP's distance from the target in nautical miles, whole because the field takes digits only.
  private static let ipDistance = "5"

  /// The seeded TOT, 18:00Z, as the keypad takes it in the target's local time (PDT).
  private static let totDigits = "110000"

  /// `UITEST_LOCATION_PATH` for the run-in, launched `runInLead` seconds before TOT. The aircraft
  /// holds 250 m left of the 179° run-in at 50 m/s, six seconds late; from TOT − 24 s it cuts back
  /// onto the course and adds speed in steps, settling at 70 m/s on the course at TOT − 12 s and
  /// crossing the target on the TOT.
  private static let runInLead: TimeInterval = 90
  private static let runInTrack = """
    [{"t":0,"lat":36.81574,"lon":-115.452021,"crs":179,"spd":50},
     {"t":66,"lat":36.78605,"lon":-115.451376,"crs":199,"spd":54},
     {"t":69,"lat":36.784672,"lon":-115.451967,"crs":199,"spd":58},
     {"t":72,"lat":36.783192,"lon":-115.452602,"crs":199,"spd":62},
     {"t":75,"lat":36.781609,"lon":-115.453281,"crs":199,"spd":66},
     {"t":78,"lat":36.779924,"lon":-115.454004,"crs":179,"spd":70},
     {"t":90,"lat":36.772367,"lon":-115.45384,"crs":179,"spd":70},
     {"t":100,"lat":36.766069,"lon":-115.453703,"crs":179,"spd":70}]
    """
  /// Seconds into the run-in track the convergence is filmed from, just before the turn back
  /// onto the course.
  private static let convergenceStart: TimeInterval = 63

  @MainActor private var app: XCUIApplication!
  @MainActor private var take: PromoTake!

  override func setUpWithError() throws {
    try super.setUpWithError()
    continueAfterFailure = false
  }

  @MainActor
  func testRecordPreview() throws {
    app = XCUIApplication()
    take = try PromoTake(app: app, tapLanding: Self.tapLanding)
    launch(
      now: UITestHarness.iso(offsetMinutes: -30),
      position: .fix(Self.targetFix),
      seeded: false
    )
    try take.startRolling()

    take.scene("target") { defineTarget() }
    take.scene("ip") { defineIP() }
    take.scene("tot") { enterTimeOnTarget() }

    relaunchOnFlyView(now: UITestHarness.iso(offsetMinutes: -15), position: .fix(Self.preIPFix))
    take.scene("push") { take.hold(Self.phaseHold) }

    relaunchOnFlyView(now: UITestHarness.iso(offsetMinutes: -7), position: .fix(Self.preIPFix))
    take.scene("speed") { take.hold(Self.phaseHold) }

    let runInStarted = relaunchOnFlyView(
      now: UITestHarness.iso(offsetSeconds: -Int(Self.runInLead)),
      position: .track(Self.runInTrack)
    )
    wait(until: runInStarted.addingTimeInterval(Self.convergenceStart))
    take.scene("converge") { take.keep { waitForPass() } }
    Thread.sleep(forTimeInterval: 0.5)
    try take.scene("pass") { try take.holdOnScreenshot(Self.phaseHold + 1) }

    try take.finish()
  }

  // MARK: - Briefing

  /// Adds a target at the aircraft's position and names it.
  @MainActor
  private func defineTarget() {
    take.tap(app.buttons["addTargetButton"], settle: Self.pageSettle)
    typeFresh(UITestHarness.seedTargetName, into: "targetNameField")
    take.hold(0.8)
  }

  /// Places the IP by bearing and distance from the target.
  @MainActor
  private func defineIP() {
    take.tap(app.buttons["defineIPButton"], settle: Self.pageSettle)
    typeFresh(String(Int(LocationHelper.IPBearingTrue)), into: "offsetBearingField")
    cut()
    take.tap(app.buttons["offsetBearingTrue"], settle: 0.4)
    typeFresh(Self.ipDistance, into: "offsetDistanceField")
    take.hold(0.6)
  }

  /// Keys in the time on target, in the target's local time.
  @MainActor
  private func enterTimeOnTarget() {
    take.tap(app.buttons["timeOnTargetButton"], settle: Self.pageSettle)
    app.segmentedControls["timeDisplayModePicker"].buttons["Target Local"].tap()
    for digit in Self.totDigits {
      take.tap(app.buttons["keypad-\(digit)"], settle: Self.keySettle)
    }
    cut()
    take.hold(1.0)
  }

  /// Empties and focuses a field off camera, then types `text` into it on camera a key at a time.
  @MainActor
  private func typeFresh(_ text: String, into identifier: String) {
    let field = app.collectionViews.firstMatch.makeVisible(element: app.textFields[identifier])!
    field.tap()
    field.tap(withNumberOfTaps: 3, numberOfTouches: 1)
    field.typeText(XCUIKeyboardKey.delete.rawValue)
    take.keep {
      for character in text {
        field.typeText(String(character))
        Thread.sleep(forTimeInterval: Self.keystroke)
      }
    }
  }

  /// Cuts away for a moment, ending the stretch the take is keeping.
  private func cut() {
    Thread.sleep(forTimeInterval: Self.cutAway)
  }

  // MARK: - Flying

  @MainActor
  @discardableResult
  private func launch(now: String, position: UITestHarness.Position, seeded: Bool = true) -> Date {
    app.launchArguments = []
    app.launchEnvironment = [:]
    let launched = Date.now
    UITestHarness.launch(app, now: now, position: position, seedTarget: seeded)
    return launched
  }

  /// Relaunches on the seeded target's Fly screen, off camera, returning when the app was launched:
  /// the moment its pinned clock reads `now`.
  @MainActor
  @discardableResult
  private func relaunchOnFlyView(now: String, position: UITestHarness.Position) -> Date {
    app.terminate()
    let launched = launch(now: now, position: position)
    UITestHarness.openFlyView(in: app)
    XCTAssert(
      app.descendants(matching: .any)["flyView"].waitForExistence(timeout: 10),
      "Fly screen should open"
    )
    return launched
  }

  @MainActor
  private func waitForPass() {
    XCTAssert(
      app.staticTexts["Past Target"].waitForExistence(timeout: Self.runInLead),
      "The pass report should appear once the track crosses the target"
    )
  }

  @MainActor
  private func wait(until moment: Date) {
    let remaining = moment.timeIntervalSinceNow
    if remaining > 0 { Thread.sleep(forTimeInterval: remaining) }
  }
}
// swiftlint:enable prefer_nimble
