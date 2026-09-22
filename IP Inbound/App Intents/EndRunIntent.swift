import AppIntents
import IP_Inbound_Shared

/// Ends the run in progress, taking down everything it holds: the countdown on the Lock Screen and
/// the watch face, the background location session, and the screen held awake.
///
/// A Fly screen left showing the ended run would be a run the pilot could no longer see ending, so
/// the flown target is sent back to the start of its setup as well.
struct EndRunIntent: AppIntent {
  static let title: LocalizedStringResource = "End Run"
  static let description: IntentDescription? = IntentDescription(
    "Ends the run you’re flying and takes its countdown off the Lock Screen and Apple Watch."
  )
  static let supportedModes: IntentModes = .background
  static let allowedExecutionTargets: IntentExecutionTargets = .main

  @MainActor
  func perform() throws -> some IntentResult & ProvidesDialog {
    guard BackgroundActivityHolder.shared.isRunOutstanding else {
      return .result(dialog: "You’re not flying a run.")
    }
    let flownTargetID = BackgroundActivityHolder.shared.runTargetID
    RunController.shared.endRun()
    if let flownTargetID { TargetNavigator.shared.show(targetID: flownTargetID, flying: false) }
    return .result(dialog: "Run ended.")
  }
}
