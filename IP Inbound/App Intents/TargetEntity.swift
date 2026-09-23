import AppIntents
import Foundation
import IP_Inbound_Shared
import MeasurementKitLocation

/// A target as Siri and Shortcuts see it: enough to name it, tell it apart from its neighbours, and
/// hand its identifier back to the app — nothing of its run-in geometry. Its coordinate is there
/// only to be shown beside it in search; guidance always reads the target afresh.
///
/// Compiled into both the iPhone and the Apple Watch app, so it is built from a `TargetSnapshot`
/// rather than the iPhone's SwiftData model.
struct TargetEntity: AppEntity {
  static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Target")
  static let defaultQuery = TargetEntityQuery()

  let id: TargetSnapshot.ID
  let name: String
  let timeOnTarget: Date?
  let coordinate: Coordinate

  /// Always in Zulu: Siri has no display-mode preference to consult on the watch, and a time spoken
  /// or shown without its zone is worse than one in the zone the pilot briefed in.
  var displayRepresentation: DisplayRepresentation {
    guard let timeOnTarget else { return DisplayRepresentation(title: "\(name)") }
    return DisplayRepresentation(
      title: "\(name)",
      subtitle: "TOT \(timeOnTarget.formatted(zuluTOTFormatStyle))"
    )
  }

  init(_ snapshot: TargetSnapshot) {
    id = snapshot.id
    name = snapshot.name
    timeOnTarget = snapshot.timeOnTarget
    coordinate = snapshot.coordinate
  }
}

/// Finds targets for Siri and Shortcuts, from whichever `TargetSource` this process registered with
/// `AppDependencyManager` at launch.
///
/// Runs only in the app itself. The source is registered in the app's initializer, which no
/// extension process ever runs; an extension asked to resolve a target would find no source at all.
struct TargetEntityQuery: EntityStringQuery, EnumerableEntityQuery {
  static let allowedExecutionTargets: IntentExecutionTargets = .main

  @Dependency var source: any TargetSource

  /// Orders targets the way a pilot reaches for them: the run being flown first, then the runs still
  /// live, soonest time on target first, then everything else by name.
  ///
  /// - Parameters:
  ///   - targets: the targets to order.
  ///   - flownID: the identifier of the target being flown, if any.
  ///   - now: the moment to judge each run's phase against.
  /// - Returns: `targets`, reordered.
  static func suggestionOrder(
    _ targets: [TargetSnapshot],
    flying flownID: TargetSnapshot.ID?,
    at now: Date
  ) -> [TargetSnapshot] {
    targets.sorted { lhs, rhs in
      let lhsRank = rank(of: lhs, flying: flownID, at: now),
        rhsRank = rank(of: rhs, flying: flownID, at: now)
      if lhsRank != rhsRank { return lhsRank < rhsRank }
      if lhsRank == .upcoming, let lhsTOT = lhs.timeOnTarget, let rhsTOT = rhs.timeOnTarget,
        lhsTOT != rhsTOT
      {
        return lhsTOT < rhsTOT
      }
      return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
  }

  private static func rank(
    of target: TargetSnapshot,
    flying flownID: TargetSnapshot.ID?,
    at now: Date
  ) -> SuggestionRank {
    if target.id == flownID { return .flown }
    switch target.status(at: now) {
      case .standingOff, .closing, .pastTOT: return .upcoming
      case .expired, nil: return .other
    }
  }

  func entities(for identifiers: [TargetEntity.ID]) async throws -> [TargetEntity] {
    try await source.targets(identifiedBy: identifiers).map(TargetEntity.init)
  }

  func entities(matching string: String) async throws -> [TargetEntity] {
    try await suggestions().filter { $0.name.localizedStandardContains(string) }
  }

  func allEntities() async throws -> [TargetEntity] {
    try await suggestions()
  }

  func suggestedEntities() async throws -> [TargetEntity] {
    try await suggestions()
  }

  private func suggestions() async throws -> [TargetEntity] {
    async let targets = source.allTargets()
    async let flown = source.flownTarget()
    return try await Self.suggestionOrder(targets, flying: flown?.id, at: Date())
      .map(TargetEntity.init)
  }
}

/// How near the front of the suggestions a target belongs, front first.
private enum SuggestionRank: Comparable {
  case flown
  case upcoming
  case other
}
