import Foundation
import Testing

@testable import IP_Inbound
@testable import IP_Inbound_Shared

private let now = Date(timeIntervalSince1970: 1_700_000_000)

private func target(_ name: String, minutesToTOT: Double?) -> TargetSnapshot {
  .init(
    id: name,
    name: name,
    latitude: 36.772367,
    longitude: -115.453840,
    offsetBearing: 0,
    offsetBearingIsTrue: true,
    offsetDistance: 4,
    targetGroundSpeed: 120,
    timeOnTarget: minutesToTOT.map { now.addingTimeInterval($0 * 60) },
    declination: 0
  )
}

@Suite
struct `Target suggestion order` {
  @Test
  func `puts the flown run first, then live runs soonest first, then the rest by name`() {
    let targets = [
      target("Zulu", minutesToTOT: nil),
      target("Later", minutesToTOT: 90),
      target("Expired", minutesToTOT: -60),
      target("Flown", minutesToTOT: 120),
      target("Alpha", minutesToTOT: nil),
      target("Sooner", minutesToTOT: 10),
      target("Just Passed", minutesToTOT: -1)
    ]

    let ordered = TargetEntityQuery.suggestionOrder(targets, flying: "Flown", at: now)

    #expect(
      ordered.map(\.name) == ["Flown", "Just Passed", "Sooner", "Later", "Alpha", "Expired", "Zulu"]
    )
  }
}
