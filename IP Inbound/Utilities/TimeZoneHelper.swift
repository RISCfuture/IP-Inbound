import CoreLocation
import Foundation
import Sentry

@MainActor
class TimeZoneHelper: NSObject {
  static let shared = TimeZoneHelper()

  private let geocoder = CLGeocoder()
  private var timeZoneCache: [String: TimeZone] = [:]

  override private init() {
    super.init()
  }

  func fetchTimeZone(
    for coordinate: Coordinate,
    completion: @escaping (TimeZone?) -> Void
  ) async {
    let cacheKey = "\(coordinate.latitudeDeg),\(coordinate.longitudeDeg)"

    if let cachedTimeZone = timeZoneCache[cacheKey] {
      completion(cachedTimeZone)
      return
    }

    let location = CLLocation(
      latitude: coordinate.latitudeDeg,
      longitude: coordinate.longitudeDeg
    )

    do {
      let placemarks = try await geocoder.reverseGeocodeLocation(location)
      if let placemark = placemarks.first,
        let timeZone = placemark.timeZone
      {
        timeZoneCache[cacheKey] = timeZone
        completion(timeZone)
      } else {
        completion(nil)
      }
    } catch {
      SentrySDK.capture(error: error) { scope in
        scope.setLevel(.warning)
        scope.setTag(value: "geocoding", key: "component")
      }
      completion(nil)
    }
  }

  func clearCache() {
    timeZoneCache.removeAll()
  }
}
