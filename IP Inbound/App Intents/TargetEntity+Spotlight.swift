import AppIntents
import CoreSpotlight
import IP_Inbound_Shared

/// A target in Spotlight is described by what a pilot would search for it by — its name, its time
/// on target and where it is — and nothing else. Bearings, distances and speeds are never searched
/// for, and feeding them to a semantic index would only dilute the name.
extension TargetEntity: IndexedEntity {
  var attributeSet: CSSearchableItemAttributeSet {
    let attributes = defaultAttributeSet
    attributes.contentDescription = searchDescription
    return attributes
  }

  private var searchDescription: String {
    [
      timeOnTarget.map { "TOT \($0.formatted(zuluTOTFormatStyle))" },
      format(coordinate: coordinate)
    ]
    .compactMap(\.self)
    .joined(separator: " · ")
  }
}

/// The system asks for a reindex when its copy is lost or stale. Every reindex is a full one, so a
/// request naming only some targets is answered the same way.
extension TargetEntityQuery: IndexedEntityQuery {
  func reindexAllEntities(indexDescription _: CSSearchableIndexDescription) async throws {
    await TargetSpotlightIndex.shared.reindex(try await source.allTargets())
  }

  func reindexEntities(
    for _: [TargetEntity.ID],
    indexDescription: CSSearchableIndexDescription
  ) async throws {
    try await reindexAllEntities(indexDescription: indexDescription)
  }
}
