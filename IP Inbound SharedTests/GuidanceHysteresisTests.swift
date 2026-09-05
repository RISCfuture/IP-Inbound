import CoreLocation
import Foundation
import MeasurementKit
import Testing

@testable import IP_Inbound_Shared

@Suite
struct `Early-arrival hysteresis` {
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  /// A lead between the release threshold and the entry threshold, where which threshold applies is
  /// the whole of the answer.
  private let leadInsideTheBand = Measurement(value: 50, unit: UnitDuration.seconds)

  /// A lead shorter than either threshold, where no countdown can stand.
  private let leadBelowTheBand = Measurement(value: 30, unit: UnitDuration.seconds)

  /// A fix a mile and a bit short of the IP, tracking down the run-in axis fast enough to count as
  /// flying. Close enough that the time on target is makeable even at the slowest speed the guidance
  /// plans to, so nothing but the early-arrival threshold decides the phase.
  private var location: CLLocation {
    .init(
      coordinate: .init(latitude: 36.872367, longitude: -115.453840),
      altitude: 5000,
      horizontalAccuracy: 5,
      verticalAccuracy: 5,
      course: 180,
      courseAccuracy: 2,
      speed: Measurement(value: 250, unit: UnitSpeed.knots).converted(to: .metersPerSecond).value,
      speedAccuracy: 1,
      timestamp: now
    )
  }

  @Test
  func `holds the countdown through a lead that dips inside the entry threshold`() throws {
    let target = try target(earlyOverTheIPBy: leadInsideTheBand)
    let arrivingOnSpeedGuidance = try guidance(for: target, following: .toIPWithSpeedGuidance)
    let arrivingOnACountdown = try guidance(for: target, following: .toIPWithCountdown)

    #expect(arrivingOnSpeedGuidance == .toIPWithSpeedGuidance)
    #expect(arrivingOnACountdown == .toIPWithCountdown)
  }

  @Test
  func `releases the countdown once the lead falls below the release threshold`() throws {
    let target = try target(earlyOverTheIPBy: leadBelowTheBand)
    let arrivingOnACountdown = try guidance(for: target, following: .toIPWithCountdown)

    #expect(arrivingOnACountdown == .toIPWithSpeedGuidance)
  }

  /// A four-point-eight-mile offset due north of the target, flown in at 120 knots.
  private func target(timeOnTarget: Date) -> TargetSnapshot {
    .init(
      id: "test",
      name: "Bullseye",
      latitude: 36.772367,
      longitude: -115.453840,
      offsetBearing: 0,
      offsetBearingIsTrue: true,
      offsetDistance: 4.8,
      targetGroundSpeed: 120,
      timeOnTarget: timeOnTarget,
      declination: 0
    )
  }

  /// A target whose desired IP crossing falls `lead` after the fix would reach the IP.
  ///
  /// Solved rather than computed: a probe reports the lead the geometry actually produces, and
  /// shifting the time on target by the difference moves it to the one the test asks for.
  private func target(earlyOverTheIPBy lead: Measurement<UnitDuration>) throws -> TargetSnapshot {
    let probe = try #require(
      GuidanceHelper(location: location, target: target(timeOnTarget: now), now: now)
    )
    return target(timeOnTarget: now + (probe.ipDeltaTime + lead))
  }

  private func guidance(for target: TargetSnapshot, following previousGuidance: Guidance) throws
    -> Guidance
  {
    try #require(
      GuidanceHelper(
        location: location,
        target: target,
        now: now,
        previousGuidance: previousGuidance
      )
    ).guidance
  }
}
