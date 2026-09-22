public import Foundation

/// Where a briefed run stands at a given moment.
///
/// Every surface that reports on a run — the complication, Siri — tells the same four-part story,
/// so the phases are judged here once rather than by each surface re-deriving them from the run's
/// dates.
public enum RunStatus: Sendable, Equatable {
  /// The time on target is far enough off that it is the whole story.
  case standingOff

  /// Within `GuidanceTarget.closingLegs` run-in legs of the time on target, where a countdown
  /// carries more than the briefed time does.
  case closing

  /// The time on target has gone by, but the run has not yet expired.
  case pastTOT

  /// The run is over.
  case expired
}

extension GuidanceTarget {
  /// The phase of this target's run at `now`.
  ///
  /// - Parameter now: the moment to judge the run against.
  /// - Returns: the run's phase, or `nil` when no time on target is briefed and there is no run to
  ///   have a phase.
  public func status(at now: Date) -> RunStatus? {
    guard timeOnTarget != nil else { return nil }
    if hasRunExpired(at: now) { return .expired }
    if hasPassedTOT(at: now) { return .pastTOT }
    if isClosing(at: now) { return .closing }
    return .standingOff
  }
}
