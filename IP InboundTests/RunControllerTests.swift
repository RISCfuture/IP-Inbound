import Foundation
import MeasurementKitLocation
import Testing

@testable import IP_Inbound

@Suite
@MainActor
struct `RunController tests` {
  private static let timeOnTarget = Date(timeIntervalSinceReferenceDate: 800_000_000)

  private func target(timeOnTarget: Date?) -> Target {
    let target = Target(name: "Test", coordinate: .zero)
    target.timeOnTarget = timeOnTarget
    return target
  }

  @Test
  func `isRunLive, flies a run through its time on target and a little past it`() {
    let target = target(timeOnTarget: Self.timeOnTarget)

    #expect(RunController.isRunLive(target, at: Self.timeOnTarget - 600))
    #expect(RunController.isRunLive(target, at: Self.timeOnTarget))
    #expect(RunController.isRunLive(target, at: Self.timeOnTarget + 60))
  }

  @Test
  func `isRunLive, abandons a run left behind long after its time on target`() {
    let target = target(timeOnTarget: Self.timeOnTarget)

    // Past the grace period nobody is flying this any more, and an unattended run that never
    // expires would have the system relaunch the app for it indefinitely.
    #expect(!RunController.isRunLive(target, at: Self.timeOnTarget + 3600))
  }

  @Test
  func `isRunLive, abandons a run whose time on target is still most of a day away`() {
    let target = target(timeOnTarget: Self.timeOnTarget)

    // A time on target is entered as a time of day and rolled forward a day once that time has
    // passed, so "still ahead of us" is true of a stale record for a full twenty-four hours. Only a
    // two-sided bound tells a run in progress from one a force-quit left behind.
    #expect(!RunController.isRunLive(target, at: Self.timeOnTarget - 86400))
  }

  @Test
  func `isRunLive, never flies a target with no time on target`() {
    // Nothing to be partway through, and nothing to bound an unattended run by.
    #expect(!RunController.isRunLive(target(timeOnTarget: nil), at: Self.timeOnTarget))
  }
}
