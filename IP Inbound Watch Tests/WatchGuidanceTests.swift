import CoreLocation
import Foundation
import IP_Inbound_Shared
import Testing

@testable import IP_Inbound_Watch

@Suite
struct `Watch guidance` {
  private func makeSnapshot() -> TargetSnapshot {
    .init(
      id: "test",
      name: "Bullseye",
      latitude: 36.772367,
      longitude: -115.453840,
      offsetBearing: 359,
      offsetBearingIsTrue: true,
      offsetDistance: 4.8,
      targetGroundSpeed: 120,
      timeOnTarget: Date(timeIntervalSince1970: 1_700_000_000),
      declination: 12.5
    )
  }

  private func location(speedKnots: Double) -> CLLocation {
    .init(
      coordinate: .init(latitude: 36.70, longitude: -115.453840),
      altitude: 5000,
      horizontalAccuracy: 5,
      verticalAccuracy: 5,
      course: 0,
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

  @Test
  func `ground speed shows the countdown; airborne speed shows the CDI`() throws {
    let snapshot = makeSnapshot()
    let taxiing = try #require(
      GuidanceHelper(location: location(speedKnots: 5), target: snapshot, now: .now)
    )
    #expect(!taxiing.isMoving)

    let airborne = try #require(
      GuidanceHelper(location: location(speedKnots: 250), target: snapshot, now: .now)
    )
    #expect(airborne.isMoving)
  }
}
