import Foundation
import IP_Inbound_Shared
import SwiftData

/// The iPhone's targets, read from the SwiftData store on a context of their own so that Siri asking
/// after a target never waits on the main thread.
@ModelActor
actor SwiftDataTargetSource: TargetSource {
  func allTargets() throws -> [TargetSnapshot] {
    try modelContext.fetch(FetchDescriptor<Target>()).map(\.snapshot)
  }

  func targets(identifiedBy ids: [TargetSnapshot.ID]) throws -> [TargetSnapshot] {
    let descriptor = FetchDescriptor<Target>(predicate: #Predicate { ids.contains($0.id) })
    return try modelContext.fetch(descriptor).map(\.snapshot)
  }

  func flownTarget() async throws -> TargetSnapshot? {
    guard let runTargetID = await BackgroundActivityHolder.shared.runTargetID else { return nil }
    return try targets(identifiedBy: [runTargetID]).first
  }
}
