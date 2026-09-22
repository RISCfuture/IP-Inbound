import Foundation
import Testing

@testable import IP_Inbound_Shared

private let timeOnTarget = Date(timeIntervalSince1970: 1_700_000_000)

private let target = TargetSnapshot(
  id: "test",
  name: "Bullseye",
  latitude: 36.772367,
  longitude: -115.453840,
  offsetBearing: 0,
  offsetBearingIsTrue: true,
  offsetDistance: 4,
  targetGroundSpeed: 120,
  timeOnTarget: timeOnTarget,
  declination: 0
)

/// A moment one second either side of one of the run's boundaries, with the phase it should read
/// as. Each phase begins at its boundary, so the boundary itself belongs to the later phase.
private struct Boundary: Sendable, CustomTestStringConvertible {
  let name: String
  let moment: @Sendable (TargetSnapshot) -> Date?
  let before: RunStatus
  let after: RunStatus

  var testDescription: String { name }
}

private let boundaries = [
  Boundary(name: "closing", moment: \.closingTime, before: .standingOff, after: .closing),
  Boundary(name: "time on target", moment: \.timeOnTarget, before: .closing, after: .pastTOT),
  Boundary(name: "expiry", moment: \.runExpiry, before: .pastTOT, after: .expired)
]

@Suite
struct `Run status` {

  @Test(arguments: boundaries)
  fileprivate func `changes phase exactly at each boundary`(_ boundary: Boundary) throws {
    let moment = try #require(boundary.moment(target))

    #expect(target.status(at: moment.addingTimeInterval(-1)) == boundary.before)
    #expect(target.status(at: moment) == boundary.after)
  }

  @Test
  func `is nothing when no time on target is briefed`() {
    let unbriefed = TargetSnapshot(
      id: "test",
      name: "Bullseye",
      latitude: 36.772367,
      longitude: -115.453840,
      offsetBearing: 0,
      offsetBearingIsTrue: true,
      offsetDistance: 4,
      targetGroundSpeed: 120,
      timeOnTarget: nil,
      declination: 0
    )

    #expect(unbriefed.status(at: timeOnTarget) == nil)
  }
}
