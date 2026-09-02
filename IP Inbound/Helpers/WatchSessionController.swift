import Foundation
import WatchConnectivity

/// Pushes the currently-flown ``Target`` to the paired Apple Watch as the WatchConnectivity
/// application context, so the watch can display run-in guidance computed from its own GPS. Only the
/// latest target is retained; clearing it (leaving the Fly screen) returns the watch to its
/// placeholder.
@MainActor
final class WatchSessionController: NSObject {
  static let shared = WatchSessionController()

  private let session: WCSession?
  private var latestContext: [String: Any]?

  override private init() {
    session =
      WCSession.isSupported() && !ProcessInfo.processInfo.isRunningPreviewsOrTests
      ? .default : nil
    super.init()
    session?.delegate = self
    session?.activate()
  }

  /// Transmits the target the pilot is flying, or clears it when `nil`.
  func update(flying target: Target?) {
    latestContext = WatchTargetPayload.context(for: target?.snapshot)
    flush()
  }

  /// Sends the retained context whenever the watch can receive it. The context is kept so that a
  /// target flown before the watch app is installed or reachable is delivered as soon as it becomes
  /// available — see ``sessionWatchStateDidChange(_:)``. `updateApplicationContext` throws while the
  /// watch app is absent; that's expected and harmless, since the next state change re-flushes.
  private func flush() {
    guard let session, session.activationState == .activated, let latestContext else { return }
    try? session.updateApplicationContext(latestContext)
  }
}

// MARK: - WCSessionDelegate

extension WatchSessionController: WCSessionDelegate {
  nonisolated func session(
    _: WCSession,
    activationDidCompleteWith _: WCSessionActivationState,
    error _: (any Error)?
  ) {
    Task { @MainActor in flush() }
  }

  /// Fires when the watch app's installed/paired/reachable state changes. Re-flushing here delivers a
  /// pending target the moment the watch becomes able to receive it.
  nonisolated func sessionWatchStateDidChange(_: WCSession) {
    Task { @MainActor in flush() }
  }

  nonisolated func sessionDidBecomeInactive(_: WCSession) {}

  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
