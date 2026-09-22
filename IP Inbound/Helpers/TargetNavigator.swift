import Foundation
import Observation

/// Carries requests to show a target from outside the view hierarchy — Siri and Shortcuts — to the
/// target list, which owns the selection and applies them.
///
/// A request is held until the list takes it, so one made while the app is still launching, before
/// the list exists, is applied when the list first appears.
@MainActor
@Observable
final class TargetNavigator {
  static let shared = TargetNavigator()

  /// The request the target list has yet to apply.
  private(set) var pending: Request?

  private init() {}

  /// Asks the target list to show a target.
  ///
  /// - Parameters:
  ///   - targetID: the target to show.
  ///   - flying: whether to open it on the Fly screen rather than at the start of its setup.
  func show(targetID: Target.ID, flying: Bool) {
    pending = Request(targetID: targetID, flying: flying)
  }

  /// Hands over the pending request, if any, and forgets it.
  func takePending() -> Request? {
    defer { pending = nil }
    return pending
  }

  /// A target to show, and where in its flow to show it.
  struct Request: Equatable {
    let targetID: Target.ID
    let flying: Bool
  }
}
