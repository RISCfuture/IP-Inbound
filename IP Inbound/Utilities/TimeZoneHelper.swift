import CoreLocation
import Foundation
import IP_Inbound_Shared
import MapKit
import MeasurementKitLocation
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
      Self.reportUnexpected(error)
      return nil
    }
  }
}

// MARK: - Error reporting

extension TimeZoneHelper {
  private static let transientURLErrorCodes: Set<Int> = [
    URLError.notConnectedToInternet.rawValue,
    URLError.networkConnectionLost.rawValue,
    URLError.timedOut.rawValue,
    URLError.cannotConnectToHost.rawValue,
    URLError.cannotFindHost.rawValue,
    URLError.dnsLookupFailed.rawValue,
    URLError.dataNotAllowed.rawValue,
    URLError.internationalRoamingOff.rawValue
  ]

  /// Reports a reverse-geocoding failure to Sentry unless it's an expected, transient
  /// error — the device being offline, a dropped connection, a MapKit service hiccup, or
  /// task cancellation — that our best-effort time-zone lookup already handles by falling
  /// back to `nil`. Reporting those only produces noise, so we drop them here.
  private static func reportUnexpected(_ error: Error) {
    guard !isExpectedGeocodingError(error) else { return }
    SentrySDK.capture(error: error) { scope in
      scope.setLevel(.warning)
      scope.setTag(value: "geocoding", key: "component")
    }
  }

  private static func isExpectedGeocodingError(_ error: Error) -> Bool {
    if error is CancellationError { return true }

    let nsError = error as NSError
    switch nsError.domain {
      case NSURLErrorDomain:
        return transientURLErrorCodes.contains(nsError.code)
      case MKError.errorDomain:
        return true  // MapKit reverse-geocoding failures are never actionable here.
      default:
        return false
    }
  }
}
