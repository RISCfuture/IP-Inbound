import CoreLocation
import Foundation
import IP_Inbound_Shared
import Testing

@testable import IP_Inbound_Watch

@Suite
struct `Watch guidance` {
  private func makeSnapshot(timeOnTarget: Date = Date(timeIntervalSince1970: 1_700_000_000))
    -> TargetSnapshot
  {
    .init(
      id: "test",
      name: "Bullseye",
      latitude: 36.772367,
      longitude: -115.453840,
      offsetBearing: 359,
      offsetBearingIsTrue: true,
      offsetDistance: 4.8,
      targetGroundSpeed: 120,
      timeOnTarget: timeOnTarget,
      declination: 12.5
    )
  }

  /// A fix on the run-in leg, between the IP north of the target and the target itself, tracking down
  /// the leg.
  private func location(speedKnots: Double) -> CLLocation {
    .init(
      coordinate: .init(latitude: 36.82, longitude: -115.453840),
      altitude: 5000,
      horizontalAccuracy: 5,
      verticalAccuracy: 5,
      course: 179,
      courseAccuracy: 2,
      speed: Measurement(value: speedKnots, unit: UnitSpeed.knots)
        .converted(to: .metersPerSecond).value,
      speedAccuracy: 1,
      timestamp: Date()
    )
  }

  @Test
  func `a snapshot survives the WatchConnectivity round trip`() throws {
    let snapshot = makeSnapshot()
    let context = WatchTargetPayload.context(for: snapshot)
    let decoded = try #require(WatchTargetPayload.snapshot(from: context))
    #expect(decoded == snapshot)
  }

  @Test
  func `an empty payload clears the target`() {
    let context = WatchTargetPayload.context(for: nil)
    #expect(WatchTargetPayload.snapshot(from: context) == nil)
  }

  /// The phase is what picks the watch's display, so it is the phase the fixtures assert: a stopped
  /// fix draws the countdown, a live run-in draws the indicator.
  @Test
  func `reads a stopped fix as the countdown and a live run-in as the run to the target`() throws {
    let snapshot = makeSnapshot(timeOnTarget: Date().addingTimeInterval(600))
    let taxiing = try #require(
      GuidanceHelper(location: location(speedKnots: 5), target: snapshot, now: .now)
    )
    #expect(taxiing.guidance == .countdownOnly)

    let airborne = try #require(
      GuidanceHelper(location: location(speedKnots: 250), target: snapshot, now: .now)
    )
    #expect(airborne.guidance == .toTarget)
  }
}
