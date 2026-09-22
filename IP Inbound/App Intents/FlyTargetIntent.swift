import AppIntents

/// Opens a target on the Fly screen.
///
/// Navigation only: the Fly screen begins the run itself when it appears, exactly as it does when
/// the pilot taps through to it. A target with no time on target yet has nothing to fly, so it opens
/// at the start of its setup instead.
struct FlyTargetIntent: AppIntent {
  static let title: LocalizedStringResource = "Fly Target"
  static let description: IntentDescription? = IntentDescription(
    "Opens a target’s Fly screen in IP Inbound."
  )
  static let supportedModes: IntentModes = .foreground(.immediate)
  static let allowedExecutionTargets: IntentExecutionTargets = .main

  static var parameterSummary: some ParameterSummary {
    Summary("Fly \(\.$target)")
  }

  @Parameter(title: "Target")
  var target: TargetEntity

  @MainActor
  func perform() throws -> some IntentResult {
    TargetNavigator.shared.show(targetID: target.id, flying: target.timeOnTarget != nil)
    return .result()
  }
}
