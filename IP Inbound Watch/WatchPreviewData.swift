import CoreLocation
import Foundation

/// Sample data for watch previews: a configured target and synthetic GPS fixes on and off course.
enum WatchPreviewData {
  static let target = TargetSnapshot(
    id: "preview",
    name: "Bullseye",
    latitude: 36.772367,
    longitude: -115.453840,
    offsetBearing: 359,
    offsetBearingIsTrue: true,
    offsetDistance: 4.8,
    targetGroundSpeed: 120,
    timeOnTarget: Date().addingTimeInterval(180),
    declination: 12
  )

  /// A fix south of the target, optionally moving and offset from the run-in course.
  static func location(
    speedKnots: Double,
    course: Double = 0,
    offsetEastNM: Double = 0
  ) -> CLLocation {
    let longitudeOffset = offsetEastNM / 60 / cos(target.latitude * .pi / 180)
    return .init(
      coordinate: .init(latitude: 36.70, longitude: -115.453840 + longitudeOffset),
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
}
