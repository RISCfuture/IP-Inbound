import AppIntents

/// Opens a target at the start of its setup. This is what the system runs when the pilot opens a
/// target it is showing them, so it takes no phrase of its own.
struct OpenTargetIntent: OpenIntent {
  static let title: LocalizedStringResource = "Open Target"
  static let description: IntentDescription? = IntentDescription("Opens a target in IP Inbound.")
  static let allowedExecutionTargets: IntentExecutionTargets = .main

  @Parameter(title: "Target")
  var target: TargetEntity

  @MainActor
  func perform() throws -> some IntentResult {
    TargetNavigator.shared.show(targetID: target.id, flying: false)
    return .result()
  }
}
