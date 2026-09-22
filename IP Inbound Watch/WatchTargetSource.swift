import Foundation
import IP_Inbound_Shared

/// The watch's targets, which are only ever the one it was last sent to fly: the watch holds no
/// target list of its own.
struct WatchTargetSource: TargetSource {
  func allTargets() -> [TargetSnapshot] {
    flownTarget().map { [$0] } ?? []
  }

  func targets(identifiedBy ids: [TargetSnapshot.ID]) -> [TargetSnapshot] {
    allTargets().filter { ids.contains($0.id) }
  }

  /// The target in the complication's store, unless its run has since expired — the store is only
  /// cleared when the phone next says so, and it may not have.
  func flownTarget() -> TargetSnapshot? {
    guard let target = WatchComplicationStore.read(), !target.hasRunExpired(at: Date()) else {
      return nil
    }
    return target
  }
}
