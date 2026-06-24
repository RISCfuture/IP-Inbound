import AsyncAlgorithms
import CoreLocation
import Observation

struct LocationEvent: Sendable {
  let location: CLLocation?
  let simName: String?
  let error: Error?

  var isSimulating: Bool { simName != nil }

  var coordinate: Coordinate? {
    guard let coordinate = location?.coordinate else { return nil }
    return .init(coordinate)
  }
  var courseTrue: Bearing? {
    location.map { location in
      .init(angle: location.course, reference: .true)
    }
  }
  var speed: Measurement<UnitSpeed>? {
    return location.map { location in
      Measurement(value: location.speed, unit: UnitSpeed.metersPerSecond)
    }
  }

  init(location: CLLocation? = nil, simName: String? = nil, error: Error? = nil) {
    self.location = location
    self.simName = simName
    self.error = error
  }

  func extrapolate(to time: Date) -> Self {
    // use course and speed to calculate new latitude and longitude
    guard let location,
      location.timestamp < time,
      let coordinate,
      let courseTrue,
      let speed = speed?.converted(to: .metersPerSecond)  // m/s
    else { return self }

    let dt = Measurement(
      value: time.timeIntervalSince(location.timestamp),
      unit: UnitDuration.seconds
    )
    let distance = speed * dt
    let newCoordinate = coordinate.offsetBy(bearing: courseTrue.angle, distance: distance)
    let accuracyChange = dt.converted(to: .seconds).value

    return .init(
      location: .init(
        coordinate: newCoordinate.toCoreLocation,
        altitude: location.altitude,
        horizontalAccuracy: location.horizontalAccuracy + accuracyChange,
        verticalAccuracy: location.verticalAccuracy + accuracyChange,
        course: location.course,
        courseAccuracy: location.courseAccuracy + accuracyChange,
        speed: location.speed,
        speedAccuracy: location.speedAccuracy + accuracyChange,
        timestamp: Date()
      ),
      simName: simName,
      error: error
    )
  }
}

@globalActor
actor LocationActor {
  static let shared = LocationActor()
}

@LocationActor
final class LocationStreamer: Sendable {
  static let shared = LocationStreamer()
  private static let simPriorityTimeout = 5.0  // seconds

  private let dateProvider: DateProvider
  private var listenerCount = 0
  private var simReceiver = SimReceiver()

  private var realLocationStream: AsyncThrowingStream<LocationEvent?, any Error>?
  private var simLocationStream: AsyncThrowingStream<LocationEvent?, any Error>?
  private var stream: AsyncThrowingStream<LocationEvent, any Error>?
  var producer: MulticastStream<LocationEvent, any Error>?

  /// Most recently emitted location event.
  private(set) var latestEvent: LocationEvent?

  private var realLocationTask: Task<Void, any Error>?
  private var simLocationTask: Task<Void, any Error>?
  private var combinedTask: Task<Void, any Error>?

  private init(dateProvider: DateProvider = .system) {
    self.dateProvider = dateProvider
  }

  func start() async {
    listenerCount += 1
    if listenerCount == 1 { await _start() }
  }

  private func _start() async {
    guard stream == nil else { return }

    await simReceiver.start()

    realLocationStream = AsyncThrowingStream { continuation in
      realLocationTask = Task {
        do {
          for try await update in CLLocationUpdate.liveUpdates(.airborne) {
            continuation.yield(LocationEvent(location: update.location))
          }
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in
        Task { @LocationActor in self.realLocationTask?.cancel() }
      }
    }

    simLocationStream = AsyncThrowingStream { continuation in
      simLocationTask = Task {
        for await sim in simReceiver.stream {
          continuation.yield(
            LocationEvent(
              location: sim.location,
              simName: sim.simName
            )
          )
        }
      }
      continuation.onTermination = { _ in
        Task { @LocationActor in self.simLocationTask?.cancel() }
      }
    }

    guard let realLocationStream, let simLocationStream else {
      await stop()
      return
    }

    let smoothRealStream = extrapolate(
      stream: realLocationStream,
      maxTime: 5,
      interval: 0.2
    ) { event, _ in
      event?.extrapolate(to: self.dateProvider.now())
    }

    // combineLatest won't emit a value until both streams have emitted at least one value
    let smoothSimStream = bootstrap(
      stream: extrapolate(
        stream: simLocationStream,
        maxTime: Self.simPriorityTimeout,
        interval: 0.2
      ) { event, _ in
        event?.extrapolate(to: self.dateProvider.now())
      },
      initial: LocationEvent()
    )

    let combined = combineLatest(smoothRealStream, smoothSimStream)
      .map { real, sim -> LocationEvent? in
        let now = self.dateProvider.now()
        let simTimedOut = sim?.location.map { $0.timestamp.timeIntervalSince(now) < -5 } ?? true
        return !simTimedOut ? sim : real
      }
      .compactMap(\.self)

    stream = AsyncThrowingStream { continuation in
      combinedTask = Task {
        do {
          for try await event in combined {
            self.latestEvent = event
            continuation.yield(event)  // Already filtered non-nil
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
      continuation.onTermination = { _ in
        Task { @LocationActor in self.combinedTask?.cancel() }
      }
    }

    producer = .init(stream: stream!)
  }

  func stop() async {
    listenerCount -= 1
    if listenerCount == 0 { await _stop() }
  }

  /// Extrapolate the most recent event forward to the current time. Callers that need a
  /// position snapshot (e.g. at the moment of a button tap) should prefer this over reading
  /// `latestEvent` directly, because the stream buffers at 200 ms intervals — at 400 kts,
  /// that's ~40 m of stale position per sample.
  func currentEvent() -> LocationEvent? {
    latestEvent?.extrapolate(to: dateProvider.now())
  }

  private func _stop() async {
    realLocationTask?.cancel()
    simLocationTask?.cancel()
    combinedTask?.cancel()
    realLocationTask = nil
    simLocationTask = nil
    combinedTask = nil

    await simReceiver.stop()

    realLocationStream = nil
    simLocationStream = nil
    stream = nil
    latestEvent = nil
  }
}
