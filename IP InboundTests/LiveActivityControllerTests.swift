import Foundation
import Testing

@testable import IP_Inbound

@Suite
@MainActor
struct `LiveActivityController tests` {
  private static let timeOnTarget = Date(timeIntervalSinceReferenceDate: 800_000_000)

  @Test
  func `armPlan, schedules a countdown a briefing ahead of its time on target`() {
    let now = Self.timeOnTarget - 3600

    #expect(
      LiveActivityController.armPlan(timeOnTarget: Self.timeOnTarget, at: now)
        == .scheduled(Self.timeOnTarget - 900)
    )
  }

  @Test
  func `armPlan, raises a countdown already inside its lead time straight away`() {
    // The setup screen bumps a stale time on target a few minutes forward, so a target briefed from
    // inside the lead time is an ordinary state rather than an edge case — and a start date in the
    // past is not one the system will schedule.
    #expect(
      LiveActivityController.armPlan(timeOnTarget: Self.timeOnTarget, at: Self.timeOnTarget - 300)
        == .immediate
    )
  }

  @Test
  func `armPlan, arms nothing for a run that cannot still be flown`() {
    #expect(LiveActivityController.armPlan(timeOnTarget: nil, at: Self.timeOnTarget) == nil)
    #expect(
      LiveActivityController.armPlan(timeOnTarget: Self.timeOnTarget, at: Self.timeOnTarget) == nil
    )
  }
}
