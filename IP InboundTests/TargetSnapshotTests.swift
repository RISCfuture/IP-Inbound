import Foundation
import Testing

@testable import IP_Inbound

@Suite("TargetSnapshot")
struct TargetSnapshotTests {
  private func makeTarget() -> Target {
    let target = Target(
      name: "Bullseye",
      coordinate: .init(latitude: 36.772367, longitude: -115.453840)
    )
    target.offsetBearing = 359
    target.offsetBearingIsTrue = true
    target.offsetDistance = 4.8
    target.targetGroundSpeed = 120
    target.timeOnTarget = Date(timeIntervalSince1970: 1_700_000_000)
    target.declination = 12.5
    target.isConfigured = true
    return target
  }

  @Test("a target's snapshot preserves its run-in geometry")
  func snapshotMatchesTarget() {
    let target = makeTarget()
    let snapshot = target.snapshot

    #expect(snapshot.coordinate == target.coordinate)
    #expect(snapshot.IPCoordinate == target.IPCoordinate)
    #expect(snapshot.IPToTarget.length == target.IPToTarget.length)
    #expect(snapshot.desiredTrackMagnetic == target.desiredTrackMagnetic)
    #expect(snapshot.desiredTimeOverIP == target.desiredTimeOverIP)
  }
}
