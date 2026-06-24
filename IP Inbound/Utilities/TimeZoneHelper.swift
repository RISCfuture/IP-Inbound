import CoreLocation
import Foundation
import MapKit
import Sentry

@MainActor
class TimeZoneHelper: NSObject {
  static let shared = TimeZoneHelper()

  private var timeZoneCache: [String: TimeZone] = [:]

  override private init() {
    super.init()
  }

  func timeZone(for coordinate: Coordinate) async -> TimeZone? {
    let cacheKey = "\(coordinate.latitudeDeg),\(coordinate.longitudeDeg)"
    if let cachedTimeZone = timeZoneCache[cacheKey] { return cachedTimeZone }

    let location = CLLocation(
      latitude: coordinate.latitudeDeg,
      longitude: coordinate.longitudeDeg
    )

    guard let request = MKReverseGeocodingRequest(location: location) else { return nil }

    do {
      let mapItems = try await request.mapItems
      guard let timeZone = mapItems.first?.timeZone else { return nil }
      timeZoneCache[cacheKey] = timeZone
      return timeZone
    } catch {
      SentrySDK.capture(error: error) { scope in
        scope.setLevel(.warning)
        scope.setTag(value: "geocoding", key: "component")
      }
      return nil
    }
  }
}
