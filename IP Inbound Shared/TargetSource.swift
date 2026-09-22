import Foundation

/// Where a process looks up the targets it knows about, for anything outside the view hierarchy that
/// needs them — Siri and Shortcuts asking after a target by name, or after the run in progress.
///
/// The iPhone and the Apple Watch each implement it over what they actually hold: the iPhone its
/// full target list, the watch only the target it was last sent to fly. Everything above this
/// protocol is written once for both.
public protocol TargetSource: Sendable {
  /// Every target this process knows about, in no particular order.
  func allTargets() async throws -> [TargetSnapshot]

  /// The targets with the given identifiers, in no particular order. An identifier that no longer
  /// names a target is skipped rather than reported.
  func targets(identifiedBy ids: [TargetSnapshot.ID]) async throws -> [TargetSnapshot]

  /// The target of the run in progress, or `nil` when none is being flown.
  func flownTarget() async throws -> TargetSnapshot?
}
