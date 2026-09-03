import Foundation
import Observation
import WatchConnectivity

/// Receives the currently-flown target from the paired iPhone over WatchConnectivity and publishes it
/// for the watch UI. Without one the watch shows its placeholder.
@MainActor
@Observable
final class WatchConnectivityModel: NSObject {
  private(set) var run = Run.unknown

  /// The flown target, or `nil` when the phone has no run in progress or has not yet said.
  var currentTarget: TargetSnapshot? {
    guard case .flying(let target) = run else { return nil }
    return target
  }

  private let session: WCSession?

  override init() {
    let seededTarget = WatchUITestSupport.seededTarget
    session = seededTarget == nil && WCSession.isSupported() ? .default : nil
    if let seededTarget { run = .flying(seededTarget) }
    super.init()
    session?.delegate = self
    session?.activate()
  }

  /// What the watch knows about the phone's run.
  ///
  /// The distinction between ``Run/unknown`` and ``Run/none`` is what keeps a launch from tearing
  /// down a run that is still going: until the session activates and reports the last thing the phone
  /// sent, "no target" is ignorance, not an answer.
  enum Run: Equatable {
    /// Before the session has reported. No conclusion to draw yet.
    case unknown

    /// The phone says no run is in progress.
    case none

    case flying(TargetSnapshot)

    init(_ target: TargetSnapshot?) {
      self = target.map(Self.flying) ?? .none
    }
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
    Task { @MainActor in run = .init(snapshot) }
  }

  nonisolated func session(
    _: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    let snapshot = WatchTargetPayload.snapshot(from: applicationContext)
    Task { @MainActor in run = .init(snapshot) }
  }
}
