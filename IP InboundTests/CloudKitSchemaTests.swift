import CloudKitSchemaTesting
import Foundation
import Testing

@testable import IP_Inbound

/// Checks the committed Production schema export against the models the app syncs. A gap is a
/// warning here and a failure in the release workflow; see `CloudKit/README.md`. The suite keeps a
/// plain identifier so the release workflow can select it with `-only-testing`.
@Suite("CloudKit schema")
struct CloudKitSchemaTests {
  private static let productionSchema = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .appending(path: "../CloudKit/schema.ckdb")
    .standardized

  @Test("Production covers every synced model")
  func productionCoversSyncedModels() {
    expectSchema(at: Self.productionSchema, covers: IP_InboundApp.syncedModels)
  }
}
