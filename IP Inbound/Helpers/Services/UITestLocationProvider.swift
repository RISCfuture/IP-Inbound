import CoreLocation
import Foundation

/// UI-test location source. Parses one of:
/// - `UITEST_LOCATION` = `lat,lon,alt,courseTrue,speed` (a single rich fix), or
/// - `UITEST_LOCATION_PATH` = JSON `[{"t":<sec>,"lat":,"lon":,"crs":,"spd":}]`
///
/// A path's coordinate is linearly interpolated between the two bracketing
/// waypoints by elapsed time from the injected ``DateProvider``; course and speed
/// come from the active segment's entering waypoint; before the first / after the
/// last waypoint the position is clamped (held, not extrapolated).
actor UITestLocationProvider: LocationProviding {
  static let fixEnvKey = "UITEST_LOCATION"
  static let pathEnvKey = "UITEST_LOCATION_PATH"

  private static let altitudeIndex = 2
  private static let courseIndex = 3
  private static let speedIndex = 4
  private static let horizontalAccuracy = 5.0
  private static let verticalAccuracy = 5.0
  private static let courseAccuracy = 1.0
  private static let speedAccuracy = 1.0
  private static let replayIntervalMS: Int = 250

  private let waypoints: [Waypoint]
  private let altitude: Double
  private let dateProvider: DateProvider
  private let launchInstant: Date

  private var continuations: [UUID: AsyncThrowingStream<LocationEvent, any Error>.Continuation] =
    [:]
  // Bounded by the number of eventStream() calls in a short-lived UI-test
  // process, so it never needs pruning.
  private var terminated: Set<UUID> = []

  init?(processInfo: ProcessInfo = .processInfo, dateProvider: DateProvider) {
    if let raw = processInfo.environment[Self.pathEnvKey],
      let data = raw.data(using: .utf8),
      let parsed = try? JSONDecoder().decode([Waypoint].self, from: data),
      !parsed.isEmpty
    {
      waypoints = parsed.sorted { $0.t < $1.t }
      altitude = 0
    } else if let raw = processInfo.environment[Self.fixEnvKey],
      let fix = Self.parseFix(raw)
    {
      waypoints = [Waypoint(t: 0, lat: fix.lat, lon: fix.lon, crs: fix.crs, spd: fix.spd)]
      altitude = fix.alt
    } else {
      return nil
    }
    self.dateProvider = dateProvider
    launchInstant = dateProvider.now()
  }

  private static func parseFix(_ value: String)
    -> (lat: Double, lon: Double, alt: Double, crs: Double, spd: Double)?
  {
    let parts = value.split(separator: ",").map {
      Double($0.trimmingCharacters(in: .whitespaces))
    }
    guard parts.count == 5, let lat = parts[0], let lon = parts[1],
      let alt = parts[Self.altitudeIndex], let crs = parts[Self.courseIndex],
      let spd = parts[Self.speedIndex]
    else { return nil }
    return (lat, lon, alt, crs, spd)
  }

  // swiftlint:disable:next async_without_await
  func start() async {}
  // swiftlint:disable:next async_without_await
  func stop() async {}

  // A scripted feed is already at full accuracy and is not gated by Core Location.
  // swiftlint:disable:next async_without_await
  func requestFullAccuracy() async {}

  // swiftlint:disable:next async_without_await
  func currentEvent() async -> LocationEvent? {
    LocationEvent(location: locationNow())
  }

  // swiftlint:disable:next async_without_await
  func eventStream() async -> AsyncThrowingStream<LocationEvent, any Error>? {
    let snapshot = locationNow()
    return AsyncThrowingStream { continuation in
      let id = UUID()
      continuation.yield(LocationEvent(location: snapshot))
      Task { await self.registerAndReplay(id: id, continuation: continuation) }
      continuation.onTermination = { _ in
        Task { await self.removeContinuation(id) }
      }
    }
  }

  private func registerAndReplay(
    id: UUID,
    continuation: AsyncThrowingStream<LocationEvent, any Error>.Continuation
  ) async {
    guard !terminated.contains(id) else { return }
    continuations[id] = continuation
    await replay(id: id)
  }

  private func removeContinuation(_ id: UUID) {
    continuations.removeValue(forKey: id)
    terminated.insert(id)
  }

  private func replay(id: UUID) async {
    // eventStream() already emitted the initial fix, so wait one interval before the first replayed
    // sample (otherwise the start fix is emitted twice). Keep emitting — clamped at the last
    // waypoint once the path ends, and from the outset for a single fix — so consumers keep
    // re-rendering as the clock advances and pick up time-driven state changes (e.g. crossing TOT).
    // A stationary aircraft still produces fixes, so a feed that fell silent would not be standing
    // in for anything Core Location does. The loop ends when the consumer cancels and the
    // continuation is removed.
    while continuations[id] != nil {
      try? await Task.sleep(for: .milliseconds(Self.replayIntervalMS))
      guard let continuation = continuations[id] else { break }
      continuation.yield(LocationEvent(location: locationNow()))
    }
  }

  private func locationNow() -> CLLocation {
    let elapsed = dateProvider.now().timeIntervalSince(launchInstant)
    let (coord, crs, spd) = sample(at: elapsed)
    return CLLocation(
      coordinate: coord,
      altitude: altitude,
      horizontalAccuracy: Self.horizontalAccuracy,
      verticalAccuracy: Self.verticalAccuracy,
      course: crs,
      courseAccuracy: Self.courseAccuracy,
      speed: spd,
      speedAccuracy: Self.speedAccuracy,
      timestamp: dateProvider.now()
    )
  }

  private func sample(at elapsed: TimeInterval)
    -> (CLLocationCoordinate2D, CLLocationDirection, CLLocationSpeed)
  {
    guard let first = waypoints.first else {
      return (CLLocationCoordinate2D(latitude: 0, longitude: 0), 0, 0)
    }
    if elapsed <= first.t || waypoints.count == 1 {
      return (
        CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon), first.crs, first.spd
      )
    }
    if let last = waypoints.last, elapsed >= last.t {
      return (CLLocationCoordinate2D(latitude: last.lat, longitude: last.lon), last.crs, last.spd)
    }
    for i in 0..<(waypoints.count - 1) {
      let a = waypoints[i], b = waypoints[i + 1]
      if elapsed >= a.t, elapsed <= b.t {
        let span = b.t - a.t
        let frac = span > 0 ? (elapsed - a.t) / span : 0
        let lat = a.lat + (b.lat - a.lat) * frac
        let lon = a.lon + (b.lon - a.lon) * frac
        return (CLLocationCoordinate2D(latitude: lat, longitude: lon), a.crs, a.spd)
      }
    }
    return (CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon), first.crs, first.spd)
  }

  struct Waypoint: Decodable, Sendable {
    let t: TimeInterval
    let lat: Double
    let lon: Double
    let crs: Double
    let spd: Double
  }
}
