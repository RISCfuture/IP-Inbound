// swiftlint:disable force_try

import CoreLocation
import SwiftData

final class PreviewHelper {
  private static let target = (36.772367, -115.453840)
  private static let preIP = (36.876930, -115.481479)
  private static let postIP = (36.8078222222, -115.4840472222)
  private static let altitude = 1502.0
  private static let headingReciprocalOffset = 180.0
  private static let course = IPBearingTrue - headingReciprocalOffset
  private static let speed = Measurement(value: 120, unit: UnitSpeed.knots)
    .converted(to: .metersPerSecond).value  // run-in speed ≈ target ground speed

  static let IPBearingTrue = 359.0

  static var preIPLocation: CLLocation {
    .init(
      coordinate: .init(latitude: Self.preIP.0, longitude: Self.preIP.1),
      altitude: Self.altitude,
      horizontalAccuracy: 1,
      verticalAccuracy: 1,
      course: Self.course,
      courseAccuracy: 1,
      speed: Self.speed,
      speedAccuracy: 1,
      timestamp: Date()
    )
  }

  static var postIPLocation: CLLocation {
    .init(
      coordinate: .init(latitude: Self.postIP.0, longitude: Self.postIP.1),
      altitude: Self.altitude,
      horizontalAccuracy: 1,
      verticalAccuracy: 1,
      course: Self.course,
      courseAccuracy: 1,
      speed: Self.speed,
      speedAccuracy: 1,
      timestamp: Date()
    )
  }

  static var groundLocation: CLLocation {
    .init(
      coordinate: .init(latitude: 36.2362000, longitude: -115.0342556),
      altitude: Self.altitude,
      horizontalAccuracy: 1,
      verticalAccuracy: 1,
      course: Self.course,
      courseAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
      timestamp: Date()
    )
  }

  let modelContainer: ModelContainer

  var groundLocation: CLLocation { Self.groundLocation }
  var preIPLocation: CLLocation { Self.preIPLocation }
  var postIPLocation: CLLocation { Self.postIPLocation }

  var groundEvent: LocationEvent { .init(location: groundLocation) }
  var preIPEvent: LocationEvent { .init(location: preIPLocation) }
  var postIPEvent: LocationEvent { .init(location: postIPLocation) }

  init() {
    modelContainer = try! .init(
      for: Target.self,
      configurations: .init(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
  }

  func target(name: String = "My Target", minutesFromNow: Double? = 4.0) -> Target {
    let target = Target(
      name: name,
      coordinate: .init(latitude: Self.target.0, longitude: Self.target.1)
    )
    if let minutesFromNow {
      target.timeOnTarget = Date().addingTimeInterval(minutesFromNow * 60)
    }
    return target
  }

  @MainActor
  func createTarget() {
    modelContainer.mainContext.insert(target(minutesFromNow: 1))
  }

  /// Inserts a mix of targets with and without a time on target, so previews exercise the
  /// list's sort order: no-TOT targets sorted by name at the top, then TOT targets by time.
  @MainActor
  func createTargets() {
    let context = modelContainer.mainContext
    context.insert(target(name: "Bravo", minutesFromNow: nil))
    context.insert(target(name: "Mike", minutesFromNow: nil))
    context.insert(target(name: "Zulu", minutesFromNow: 3))
    context.insert(target(name: "Alpha", minutesFromNow: 9))
  }
}

// swiftlint:enable force_try
