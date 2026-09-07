import Foundation
import Testing

@testable import IP_Inbound_Shared

private let timeOnTarget = Date(timeIntervalSince1970: 1_700_000_000)

/// A four-mile offset flown at 120 knots is a two-minute run-in.
private func target(
  timeOnTarget: Date?,
  targetGroundSpeed: Double = 120,
  offsetDistance: Double = 4
) -> TargetSnapshot {
  .init(
    id: "test",
    name: "Bullseye",
    latitude: 36.772367,
    longitude: -115.453840,
    offsetBearing: 0,
    offsetBearingIsTrue: true,
    offsetDistance: offsetDistance,
    targetGroundSpeed: targetGroundSpeed,
    timeOnTarget: timeOnTarget,
    declination: 0
  )
}

@Suite
struct `Run-in window` {

  @Test
  func `runs from the desired IP crossing through the time on target`() throws {
    let window = try #require(target(timeOnTarget: timeOnTarget).runInWindow)

    #expect(window.upperBound == timeOnTarget)
    #expect(abs(window.lowerBound.timeIntervalSince(timeOnTarget) + 120) < 1)
  }

  @Test
  func `is nothing when no time on target is briefed`() {
    #expect(target(timeOnTarget: nil).runInWindow == nil)
  }

  @Test
  func `is nothing when the run-in leg has no finite duration`() {
    // A target with no ground speed divides to an infinite run-in, which is not a range anyone can
    // be shown — and building a `ClosedRange` from it would be a bound the Smart Stack never leaves.
    #expect(target(timeOnTarget: timeOnTarget, targetGroundSpeed: 0).runInWindow == nil)
  }
}

@Suite
struct `Closing time` {
  @Test
  func `falls two run-in legs before the time on target`() throws {
    let closingTime = try #require(target(timeOnTarget: timeOnTarget).closingTime)

    #expect(abs(closingTime.timeIntervalSince(timeOnTarget) + 240) < 1)
  }

  @Test
  func `is nothing when the run-in leg has no finite duration`() {
    #expect(target(timeOnTarget: timeOnTarget, targetGroundSpeed: 0).closingTime == nil)
  }

  @Test
  func `closes only once the run is within two legs of its time on target`() {
    let target = target(timeOnTarget: timeOnTarget)

    #expect(!target.isClosing(at: timeOnTarget.addingTimeInterval(-241)))
    #expect(target.isClosing(at: timeOnTarget.addingTimeInterval(-239)))
  }

  @Test
  func `never closes when the run-in leg has no finite duration`() {
    // No leg to scale a ring against, so the briefed time is all there is to show, at any range.
    let target = target(timeOnTarget: timeOnTarget, targetGroundSpeed: 0)

    #expect(!target.isClosing(at: timeOnTarget))
  }
}
