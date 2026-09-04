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

  /// The flown target, or `nil` when the phone has no run in progress, has not yet said, or named
  /// a run that has since expired.
  var currentTarget: TargetSnapshot? {
    guard case .flying(let target) = run else { return nil }
    return target
  }

  private let session: WCSession?

  private var expiryTask: Task<Void, Never>?

  override init() {
    let seededTarget = WatchUITestSupport.seededTarget
    session = seededTarget == nil && WCSession.isSupported() ? .default : nil
    super.init()
    if let seededTarget { fly(seededTarget) }
    session?.delegate = self
    session?.activate()
  }

  /// Publishes what the phone just said, and hands the same answer to the complication.
  ///
  /// Both delegate paths land here, so the watch face and the watch app can never be told different
  /// things. The store is handed what the phone said rather than what the app concluded from it: the
  /// complication does its own judging, and ``Run/unknown`` — which would blank a face that is still
  /// perfectly correct — is by construction never something the phone can say.
  private func receive(_ snapshot: TargetSnapshot?) {
    WatchComplicationStore.update(snapshot)
    fly(snapshot)
  }

  /// Publishes a run and schedules its own end, or stands the run down when there is none left to
  /// fly.
  ///
  /// The watch cannot wait to be told the run is over. Everything it holds for one — its GPS, its
  /// background session, the indicator lit at the top of the face — is released on the phone's word,
  /// and the phone may have been force-quit, may be out of range, or may have spent the transfer
  /// budget the system meters. That is the same reason the complication judges its stored snapshot
  /// against the clock rather than trusting it to be current; the app judges the run it is flying
  /// the same way, so the face and the app cannot disagree about whether there is still a run.
  private func fly(_ snapshot: TargetSnapshot?) {
    expiryTask?.cancel()
    expiryTask = nil

    guard let snapshot, !snapshot.hasRunExpired(at: .now) else {
      run = .none
      return
    }

    run = .flying(snapshot)
    armExpiry(for: snapshot)
  }

  /// Stands the run down at its expiry. A snapshot with no time on target has no run to bound, and
  /// one already past its expiry never reaches here.
  private func armExpiry(for snapshot: TargetSnapshot) {
    guard let runExpiry = snapshot.runExpiry else { return }
    let remaining = runExpiry.timeIntervalSinceNow

    expiryTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(remaining))
      guard !Task.isCancelled else { return }
      self?.fly(nil)
    }
  }

  /// What the watch knows about the phone's run.
  ///
  /// The distinction between ``Run/unknown`` and ``Run/none`` is what keeps a launch from tearing
  /// down a run that is still going: until the session activates and reports the last thing the phone
  /// sent, "no target" is ignorance, not an answer.
  enum Run: Equatable {
    /// Before the session has reported. No conclusion to draw yet.
    case unknown

    /// Nothing to fly: the phone says no run is in progress, or the run it last named has expired.
    case none

    case flying(TargetSnapshot)
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
