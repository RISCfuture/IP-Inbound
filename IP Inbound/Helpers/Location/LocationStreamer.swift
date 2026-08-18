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
  /// `nil` when the fix carries no usable course. `CLLocation` signals that with a negative value,
  /// which taken at face value would point the run-in a degree west of north.
  var courseTrue: Bearing? {
    guard let location, location.course >= 0 else { return nil }
    return .init(angle: location.course, reference: .true)
  }

  /// `nil` when the fix carries no usable speed. `CLLocation` signals that with a negative value,
  /// which taken at face value would dead-reckon the aircraft backwards along its track.
  var speed: Measurement<UnitSpeed>? {
    guard let location, location.speed >= 0 else { return nil }
    return .init(value: location.speed, unit: .metersPerSecond)
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
      let speed
    else { return self }

    let elapsed = time - location.timestamp
    let distance = speed * elapsed
    let newCoordinate = coordinate.offsetBy(bearing: courseTrue.angle, distance: distance)
    let accuracy = DeadReckonedAccuracy(
      fix: location,
      groundSpeed: speed,
      traveled: distance,
      elapsed: elapsed
    )

    return .init(
      location: .init(
        coordinate: newCoordinate.toCoreLocation,
        altitude: location.altitude,
        horizontalAccuracy: accuracy.horizontal,
        verticalAccuracy: accuracy.vertical,
        course: location.course,
        courseAccuracy: accuracy.course,
        speed: location.speed,
        speedAccuracy: accuracy.speed,
        // The propagated fix is an estimate of where the aircraft is at `time`, so that is when it
        // is valid — stamping it with the wall clock instead would misdate it against a simulated
        // one, and staleness is judged against the same clock `time` comes from.
        timestamp: time
      ),
      simName: simName,
      error: error
    )
  }
}

/// How a fix's reported accuracies decay while ``LocationEvent/extrapolate(to:)`` dead-reckons it
/// forward — the process noise of a constant-velocity propagation.
///
/// Position is genuinely propagated, so its error grows the way dead-reckoning error always does: the
/// speed error integrates along track (`σᵥ·Δt`), and the course error swings the distance traveled
/// across it (`d·σ_c`).
///
/// Altitude, course and ground speed are *not* propagated — they are carried forward unchanged — so
/// their error grows with whatever the aircraft may have done since the fix. That is bounded by
/// ``maneuverAcceleration``: a climb or descent displaces by `½aΔt²`, a turn swings the ground track
/// at `a/v`, and a longitudinal acceleration moves the speed by `a·Δt`. The turn term is the model's
/// actual turn rate; the vertical and speed terms treat the same figure as a conservative envelope,
/// since nothing in a `CLLocation` observes vertical rate or longitudinal acceleration.
///
/// Independent terms combine in quadrature. A `CLLocation` accuracy is negative when the device could
/// not determine it; those sentinels pass through untouched, and contribute nothing where they feed
/// another term.
private struct DeadReckonedAccuracy {
  /// Bound on the acceleration the aircraft may apply between fixes. The guidance already models it
  /// as able to hold a level turn at ``FromToMath/bankAngle``; the lateral acceleration that implies
  /// is the strongest maneuver it expects, so it doubles as the envelope for climb, descent and
  /// speed change.
  private static var maneuverAcceleration: Measurement<UnitAcceleration> {
    FromToMath.turnAcceleration
  }

  /// The course uncertainty at which the direction of travel carries no information at all.
  private static let unknownCourse = Measurement(value: 180, unit: UnitAngle.degrees)

  let fix: CLLocation
  let groundSpeed: Measurement<UnitSpeed>
  let traveled: Measurement<UnitLength>
  let elapsed: Measurement<UnitDuration>

  var horizontal: CLLocationAccuracy {
    grown(
      fix.horizontalAccuracy,
      by: [alongTrackError, crossTrackError].map { $0.converted(to: .meters).value }
    )
  }

  var vertical: CLLocationAccuracy {
    grown(fix.verticalAccuracy, by: [verticalError.converted(to: .meters).value])
  }

  /// Capped at a half-turn: past that the course is simply unknown, and a larger figure would claim
  /// a precision the model cannot have.
  var course: CLLocationDirectionAccuracy {
    let grownCourse = grown(fix.courseAccuracy, by: [turnError.converted(to: .degrees).value])
    return min(grownCourse, Self.unknownCourse.converted(to: .degrees).value)
  }

  var speed: CLLocationSpeedAccuracy {
    grown(fix.speedAccuracy, by: [speedError.converted(to: .metersPerSecond).value])
  }

  /// The speed error integrated over the elapsed time, displacing the fix along its track.
  private var alongTrackError: Measurement<UnitLength> {
    guard fix.speedAccuracy >= 0 else { return .zero }
    return Measurement(value: fix.speedAccuracy, unit: UnitSpeed.metersPerSecond) * elapsed
  }

  /// The course error swung across the distance traveled. Uses the arc rather than the chord, which
  /// errs high — the safe direction for an uncertainty.
  private var crossTrackError: Measurement<UnitLength> {
    guard fix.courseAccuracy >= 0 else { return .zero }
    return traveled * Measurement(value: fix.courseAccuracy, unit: UnitAngle.degrees).radians
  }

  /// The displacement an unobserved climb or descent at the maneuver bound reaches: `½aΔt²`.
  private var verticalError: Measurement<UnitLength> {
    Self.maneuverAcceleration * elapsed * elapsed * 0.5
  }

  /// The ground track a turn at the maneuver bound sweeps. Turn rate is `a/v`, so the time to turn
  /// one radian is `v/a` and the angle swept is `Δt` measured in those. A stationary aircraft has no
  /// ground track to swing.
  private var turnError: Measurement<UnitAngle> {
    guard groundSpeed > .zero else { return .zero }
    return .init(value: elapsed / (groundSpeed / Self.maneuverAcceleration), unit: .radians)
  }

  /// The speed change an unobserved longitudinal acceleration at the maneuver bound reaches.
  private var speedError: Measurement<UnitSpeed> {
    Self.maneuverAcceleration * elapsed
  }

  /// Combines independent uncertainties in quadrature, passing a negative — meaning unavailable —
  /// accuracy through untouched.
  private func grown(_ accuracy: Double, by terms: [Double]) -> Double {
    guard accuracy >= 0 else { return accuracy }
    return terms.reduce(accuracy * accuracy) { $0 + $1 * $1 }.squareRoot()
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
