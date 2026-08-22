import CoreLocation
import Foundation

/// Sample data for watch previews: a configured target and synthetic GPS fixes on and off course.
enum WatchPreviewData {
  /// The run-in track, the reciprocal of the target's offset bearing. The IP lies north of the
  /// target, so the leg is flown southbound — which puts east of the course line to the *left* of
  /// it.
  static let runInCourse = 179.0

  private static let targetLatitude = 36.772367,
    targetLongitude = -115.453840

  /// A fix on the run-in leg, between the IP and the target.
  private static let fixLatitude = 36.82

  static let target = TargetSnapshot(
    id: "preview",
    name: "Bullseye",
    latitude: targetLatitude,
    longitude: targetLongitude,
    offsetBearing: 359,
    offsetBearingIsTrue: true,
    offsetDistance: 4.8,
    targetGroundSpeed: 120,
    timeOnTarget: Date().addingTimeInterval(180),
    declination: 12
  )

  /// A fix inbound on the run-in leg, optionally offset from the course line.
  static func location(
    speedKnots: Double,
    course: Double = runInCourse,
    offsetEastNM: Double = 0
  ) -> CLLocation {
    let longitudeOffset = offsetEastNM / 60 / cos(targetLatitude * .pi / 180)
    return .init(
      coordinate: .init(latitude: fixLatitude, longitude: targetLongitude + longitudeOffset),
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

  /// The run-in geometry for a fix on ``target``, for previews that draw the indicator directly.
  ///
  /// - Parameters:
  ///   - speedKnots: the fix's ground speed.
  ///   - offsetEastNM: how far east of the course line the fix lies.
  /// - Returns: the geometry, or `nil` if the fix carries no usable ground speed or course.
  static func math(
    speedKnots: Double = 250,
    offsetEastNM: Double = 0
  ) -> IPTargetMath<TargetSnapshot>? {
    IPTargetMath(
      location: location(speedKnots: speedKnots, offsetEastNM: offsetEastNM),
      target: target,
      now: Date()
    )
  }
}
