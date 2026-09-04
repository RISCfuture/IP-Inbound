import AsyncAlgorithms
import CoreLocation
import IP_Inbound_Shared
import MeasurementKit
import MeasurementKitLocation
import Observation

struct LocationEvent: Sendable {
  let location: CLLocation?
  let simName: String?
  let error: Error?

  /// Why Core Location is withholding a usable fix. `.clean` for a simulator feed, which Core
  /// Location does not gate.
  let diagnostics: LocationDiagnostics

  var isSimulating: Bool { simName != nil }

  var coordinate: Coordinate? { location?.geoCoordinate }

  /// `nil` when the fix carries no usable course. `CLLocation` signals that with a negative value,
  /// which taken at face value would point the run-in a degree west of north.
  var courseTrue: TrueBearing? { location?.courseTrue }

  /// `nil` when the fix carries no usable speed. `CLLocation` signals that with a negative value,
  /// which taken at face value would dead-reckon the aircraft backwards along its track.
  var speed: Measurement<UnitSpeed>? { location?.groundSpeed }

  init(
    location: CLLocation? = nil,
    simName: String? = nil,
    error: Error? = nil,
    diagnostics: LocationDiagnostics = .clean
  ) {
    self.location = location
    self.simName = simName
    self.error = error
    self.diagnostics = diagnostics
  }

  func extrapolate(to time: Date) -> Self {
    // use course and speed to calculate new latitude and longitude
    guard let location,
      location.timestamp < time,
      let coordinate,
      let courseTrue,
      let speed
    else { return self }

    let elapsed = time.elapsed(since: location.timestamp)
    let distance = speed * elapsed
    let newCoordinate = coordinate.offset(bearing: courseTrue, distance: distance)
    let accuracy = DeadReckonedAccuracy(
      fix: location,
      groundSpeed: speed,
      traveled: distance,
      elapsed: elapsed
    )

    return .init(
      location: .init(
        coordinate: newCoordinate.clCoordinate,
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
      error: error,
      diagnostics: diagnostics
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
  /// as able to hold a level turn at `FromToMath.bankAngle`; the lateral acceleration that implies
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
    guard let speedAccuracy = fix.speedAccuracyMeasurement else { return .zero }
    return speedAccuracy * elapsed
  }

  /// The course error swung across the distance traveled. Uses the arc rather than the chord, which
  /// errs high — the safe direction for an uncertainty.
  private var crossTrackError: Measurement<UnitLength> {
    guard let courseAccuracy = fix.courseAccuracyAngle else { return .zero }
    return traveled * courseAccuracy.radians
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
  private static let fullAccuracyPurposeKey = "CourseGuidance"

  /// How long the stream outlives its last listener before it is torn down.
  ///
  /// Flying on to the next target rebuilds the entire setup flow, and SwiftUI promises nothing about
  /// whether the departing subtree lets go before the arriving one takes hold. A release that lands
  /// first would take the tally to zero mid-run and tear down a stream that is about to be asked
  /// for again — dropping the full-accuracy session with it, and putting the precise-location prompt
  /// back in front of a pilot who is flying. A hold taken inside this window finds the stream still
  /// running and costs nothing; nobody taking one leaves the teardown no later than it would have
  /// been.
  private static let teardownGrace = Duration.milliseconds(500)

  private let dateProvider: DateProvider
  private var listenerCount = 0
  private var teardownTask: Task<Void, Never>?
  private var simReceiver = SimReceiver()

  private var realLocationStream: AsyncThrowingStream<LocationEvent?, any Error>?
  private var simLocationStream: AsyncThrowingStream<LocationEvent?, any Error>?
  private var stream: AsyncThrowingStream<LocationEvent, any Error>?
  var producer: MulticastStream<LocationEvent, any Error>?

  /// Most recently emitted location event.
  private(set) var latestEvent: LocationEvent?

  /// Retained for as long as the run needs full accuracy: Core Location drops the temporary grant
  /// the moment the session is released, so this cannot be a local in `requestFullAccuracy()`.
  private var fullAccuracySession: CLServiceSession?

  private var realLocationTask: Task<Void, any Error>?
  private var simLocationTask: Task<Void, any Error>?
  private var combinedTask: Task<Void, any Error>?

  private init(dateProvider: DateProvider = .system) {
    self.dateProvider = dateProvider
  }

  /// Takes a listener's hold on the stream, starting it for the first one.
  func start() async {
    teardownTask?.cancel()
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
            continuation.yield(
              LocationEvent(location: update.location, diagnostics: .init(update))
            )
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

  /// Releases one listener's hold, tearing the stream down `teardownGrace` after the last one lets
  /// go.
  ///
  /// A release with no hold outstanding is ignored rather than counted. `NeedsLocationView` starts
  /// the stream from a `task` and stops it from `onDisappear`, and a view that appears and
  /// disappears within one runloop turn has its `task` cancelled before it ever starts — so the
  /// release can genuinely arrive first. Counted, that would leave the tally below zero, where
  /// ``start()`` can never see it reach one again and the app produces no fixes for the rest of the
  /// process.
  func stop() {
    guard listenerCount > 0 else { return }
    listenerCount -= 1
    if listenerCount == 0 { scheduleTeardown() }
  }

  private func scheduleTeardown() {
    teardownTask = Task { [weak self] in
      try? await Task.sleep(for: Self.teardownGrace)
      guard !Task.isCancelled else { return }
      await self?.teardownIfUnheld()
    }
  }

  /// Tears the stream down unless a listener has taken it over in the meantime. The tally is read
  /// here rather than in the waiting task so that a hold taken while this was already on its way to
  /// the actor still saves the stream.
  private func teardownIfUnheld() async {
    guard listenerCount == 0 else { return }
    await _stop()
  }

  /// Requests temporary full accuracy, naming the purpose key that
  /// `NSLocationTemporaryUsageDescriptionDictionary` explains to the pilot. Repeated calls reuse the
  /// outstanding session rather than stacking prompts.
  func requestFullAccuracy() {
    guard fullAccuracySession == nil else { return }
    fullAccuracySession = .init(
      authorization: .whenInUse,
      fullAccuracyPurposeKey: Self.fullAccuracyPurposeKey
    )
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

    fullAccuracySession?.invalidate()
    fullAccuracySession = nil

    // Consumers hold streams vended by this producer, and a restart installs a new one. Left
    // running, the old producer would keep those consumers attached to a broadcast that has no
    // source — silent rather than finished, so nothing downstream ever learns the fixes stopped.
    await producer?.stop()
    producer = nil

    realLocationStream = nil
    simLocationStream = nil
    stream = nil
    latestEvent = nil
  }
}
