import Foundation
import IP_Inbound_Shared
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

  /// Publishes what the phone just said, and hands the same answer to the complication.
  ///
  /// Both delegate paths land here, so the watch face and the watch app can never be told different
  /// things. ``Run/unknown`` never reaches the store by construction: it is the value the model
  /// starts at, and ``Run/init(_:)`` cannot produce it — which matters, because writing it would
  /// blank a complication that is still perfectly correct.
  private func receive(_ snapshot: TargetSnapshot?) {
    run = .init(snapshot)
    WatchComplicationStore.update(snapshot)
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
    Task { @MainActor in receive(snapshot) }
  }

  nonisolated func session(
    _: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    let snapshot = WatchTargetPayload.snapshot(from: applicationContext)
    Task { @MainActor in receive(snapshot) }
  }

  /// The complication-priority delivery the phone sends alongside the application context. It
  /// carries the same payload; arriving here wakes the watch app to refresh the watch face when the
  /// pilot has not opened it.
  nonisolated func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
    let snapshot = WatchTargetPayload.snapshot(from: userInfo)
    Task { @MainActor in receive(snapshot) }
  }
}
