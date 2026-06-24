import Foundation
import Observation
import WatchConnectivity

/// Receives the currently-flown target from the paired iPhone over WatchConnectivity and publishes it
/// for the watch UI. `nil` means no flight is in progress, so the watch shows its placeholder.
@MainActor
@Observable
final class WatchConnectivityModel: NSObject {
  private(set) var currentTarget: TargetSnapshot?

  private let session: WCSession?

  override init() {
    let seededTarget = WatchUITestSupport.seededTarget
    session = seededTarget == nil && WCSession.isSupported() ? .default : nil
    currentTarget = seededTarget
    super.init()
    session?.delegate = self
    session?.activate()
  }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityModel: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith _: WCSessionActivationState,
    error _: (any Error)?
  ) {
    let snapshot = WatchTargetPayload.snapshot(from: session.receivedApplicationContext)
    Task { @MainActor in currentTarget = snapshot }
  }

  nonisolated func session(
    _: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    let snapshot = WatchTargetPayload.snapshot(from: applicationContext)
    Task { @MainActor in currentTarget = snapshot }
  }
}
