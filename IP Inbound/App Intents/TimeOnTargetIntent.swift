import AppIntents
import Foundation
import IP_Inbound_Shared

/// Tells the pilot how long until a target's time on target — the run being flown, unless they name
/// another.
///
/// Compiled into both the iPhone and the Apple Watch app, so it reaches targets only through
/// `TargetSource` and knows nothing of either app's own model.
struct TimeOnTargetIntent: AppIntent {
  static let title: LocalizedStringResource = "Time on Target"
  static let description: IntentDescription? = IntentDescription(
    "Tells you how long until the time on target of the run you’re flying, or of a target you choose."
  )
  static let supportedModes: IntentModes = .background
  static let allowedExecutionTargets: IntentExecutionTargets = .main

  private static let remainingFormat = Duration.UnitsFormatStyle(
    allowedUnits: [.hours, .minutes, .seconds],
    width: .wide,
    maximumUnitCount: 2
  )

  static var parameterSummary: some ParameterSummary {
    Summary("Time on target for \(\.$target)")
  }

  @Parameter(title: "Target")
  var target: TargetEntity?

  @Dependency private var source: any TargetSource

  /// What to tell the pilot about `target`'s run at `now`.
  static func dialog(for target: TargetSnapshot, at now: Date) -> IntentDialog {
    guard let timeOnTarget = target.timeOnTarget, let status = target.status(at: now) else {
      return "\(target.name) has no time on target."
    }
    let zulu = timeOnTarget.formatted(zuluTOTFormatStyle),
      interval = Duration.seconds(abs(timeOnTarget.timeIntervalSince(now)).rounded())
        .formatted(remainingFormat)
    switch status {
      case .standingOff, .closing:
        return "\(target.name)’s time on target is \(zulu), in \(interval)."
      case .pastTOT:
        return "\(target.name)’s time on target was \(zulu), \(interval) ago."
      case .expired:
        return "\(target.name)’s time on target was \(zulu)."
    }
  }

  func perform() async throws -> some IntentResult & ProvidesDialog {
    guard let snapshot = try await resolvedTarget() else {
      return .result(dialog: "You’re not flying a run.")
    }
    return .result(dialog: Self.dialog(for: snapshot, at: Date()))
  }

  private func resolvedTarget() async throws -> TargetSnapshot? {
    guard let target else { return try await source.flownTarget() }
    return try await source.targets(identifiedBy: [target.id]).first
  }
}
