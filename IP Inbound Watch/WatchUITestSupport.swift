import CoreLocation
import Foundation

/// Parses launch-environment seeds so watch UI tests can drive the guidance views deterministically,
/// bypassing WatchConnectivity and live GPS. Active only under the `-UITests` launch argument, so it
/// never affects production runs.
enum WatchUITestSupport {
  private static let seededLatitude = 36.70
  private static let targetLatitude = 36.772367
  private static let targetLongitude = -115.453840

  static var isActive: Bool {
    ProcessInfo.processInfo.isRunningUITests
  }

  /// The seeded target, when `UITEST_WATCH_SEED_TARGET=1`. Its IP lies due south of the target so a
  /// fix between them, tracking north, flies a sensible run-in. `UITEST_WATCH_TOT_OFFSET` (seconds)
  /// sets how far in the future the time-on-target is.
  static var seededTarget: TargetSnapshot? {
    guard isActive, value(for: "UITEST_WATCH_SEED_TARGET") == "1" else { return nil }
    let totOffset = double(for: "UITEST_WATCH_TOT_OFFSET") ?? 600
    return .init(
      id: "uitest",
      name: "Bullseye",
      latitude: targetLatitude,
      longitude: targetLongitude,
      offsetBearing: 180,
      offsetBearingIsTrue: true,
      offsetDistance: 4.8,
      targetGroundSpeed: 120,
      timeOnTarget: Date().addingTimeInterval(totOffset),
      declination: 0
    )
  }

  /// The seeded GPS fix, when `UITEST_WATCH_SPEED_KTS` is supplied. Ground speed selects the
  /// countdown vs. CDI; `UITEST_WATCH_COURSE` and `UITEST_WATCH_OFFSET_EAST_NM` tune the track and
  /// cross-track.
  static var seededLocation: CLLocation? {
    guard isActive, let speedKnots = double(for: "UITEST_WATCH_SPEED_KTS") else { return nil }
    let course = double(for: "UITEST_WATCH_COURSE") ?? 0
    let offsetEastNM = double(for: "UITEST_WATCH_OFFSET_EAST_NM") ?? 0
    let longitudeOffset = offsetEastNM / 60 / cos(seededLatitude * .pi / 180)
    return .init(
      coordinate: .init(latitude: seededLatitude, longitude: targetLongitude + longitudeOffset),
      altitude: 5000,
      horizontalAccuracy: 5,
      verticalAccuracy: 5,
      course: course,
      courseAccuracy: 2,
      speed: Measurement(value: speedKnots, unit: UnitSpeed.knots)
        .converted(to: .metersPerSecond).value,
      speedAccuracy: 1,
      timestamp: Date()
    )
  }

  private static func value(for key: String) -> String? {
    ProcessInfo.processInfo.environment[key]
  }

  private static func double(for key: String) -> Double? {
    value(for: key).flatMap(Double.init)
  }
}
