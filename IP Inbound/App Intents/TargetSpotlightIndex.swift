import AppIntents
import CoreSpotlight
import Foundation
import IP_Inbound_Shared
import Sentry

/// Keeps Spotlight's copy of the targets in step with the store.
///
/// Every reindex is a full one. A few dozen targets cost nothing to index, and indexing all of them
/// each time means an out-of-order sync merge or a missed change can never leave an entry stale.
/// Indexing only ever adds, though, so targets that have gone are deleted by difference with what
/// was last indexed — and since a target can be deleted while the app is not running, the first
/// reindex in a process starts from an empty index rather than trusting what it finds.
actor TargetSpotlightIndex {
  static let shared = TargetSpotlightIndex()

  /// What this process last indexed, or `nil` before its first reindex.
  private var indexedIDs: Set<TargetSnapshot.ID>?

  private init() {}

  /// Makes Spotlight's targets exactly `targets`.
  ///
  /// - Parameter targets: every target in the store.
  func reindex(_ targets: [TargetSnapshot]) async {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests else { return }
    let ids = Set(targets.map(\.id))
    do {
      try await removeTargets(notIn: ids)
      try await CSSearchableIndex.default().indexAppEntities(targets.map(TargetEntity.init))
      indexedIDs = ids
    } catch {
      SentrySDK.capture(error: error)
    }
  }

  private func removeTargets(notIn ids: Set<TargetSnapshot.ID>) async throws {
    guard let indexedIDs else {
      try await CSSearchableIndex.default().deleteAppEntities(ofType: TargetEntity.self)
      return
    }
    let vanished = indexedIDs.subtracting(ids)
    guard !vanished.isEmpty else { return }
    try await CSSearchableIndex.default().deleteAppEntities(
      identifiedBy: Array(vanished),
      ofType: TargetEntity.self
    )
  }
}
