import CoreLocation
import Foundation
import IP_Inbound_Shared
import MeasurementKit
import SwiftData
import UIKit

/// Owns the run: what it holds while it lasts, and when it stops lasting.
///
/// A run holds a great deal — the screen awake, the location stream alive once the app stops being
/// frontmost, a countdown on the Lock Screen and on the watch face — and none of it belongs to the
/// screen that happens to be showing. ``beginRun(flying:)`` raises all of it together and
/// ``endRun()`` releases all of it together, so there is one answer to "is a run live?" rather than
/// one per resource.
///
/// Every run is bounded at both ends, by the window ``isRunLive(_:at:)`` draws. Left to the Fly
/// screen alone a run would last from whenever the screen was opened until the pilot navigated
/// away, and backgrounding the app does not do that — the background session is exactly what keeps
/// the process alive — so a phone pocketed on that screen would hold the airborne GPS
/// configuration through a brief hours before the run and through the flight home after it. The
/// window opens a set lead before the time on target and closes at
/// `GuidanceTarget.runExpiry`, and the run is over then whether or not anyone is looking.
///
/// It also flies the run when there is no screen to fly it. The guidance the pilot reads is solved
/// in `FlyView`'s body, which is the right place for it while there is a body to solve it in. There
/// is not always: Core Location relaunches the app in the background when a run outlives the
/// process, and that launch connects no scene, so no view is ever built. Left at that, the run-in
/// figures on the Lock Screen freeze at whatever they read when the process died, and stay frozen
/// until the pilot next looks at the phone.
///
/// So ``resumeRunInProgress(in:)`` drives the same figures from the same stream with nothing on
/// screen, and steps aside the moment the Fly screen appears, because two solvers reading two fixes
/// would let the Lock Screen and the CDI disagree. It does not re-request the Live Activity:
/// starting one is foreground-only, so a run whose activity did not survive the relaunch has nowhere
/// to draw and this quietly pushes into an empty collection.
@MainActor
final class RunController {
  static let shared = RunController()

  /// How long before the planned time-on-target a recorded run is still worth resuming.
  ///
  /// The bound is two-sided because a time-on-target is entered as a time of day and rolled forward
  /// a day when that time has already passed, so a target a full day out is an ordinary state rather
  /// than a stale one. Judged only on "is it still ahead?", a run left behind by a force-quit would
  /// be resumed on every launch for the next twenty-four hours.
  private static let maxLead = Measurement(value: 2, unit: UnitDuration.hours)

  private var runTask: Task<Void, Never>?
  private var startTask: Task<Void, Never>?
  private var expiryTask: Task<Void, Never>?

  /// The target whose window this process is waiting on, so a screen leaving can tell a start of
  /// its own from one the screen replacing it has just armed.
  private var pendingStartTargetID: String?

  /// The last figures pushed, so a fix that would not move the Lock Screen's readout is not sent.
  /// `RunInSnapshot` is already rounded to the precision it displays at.
  private var lastPushed: RunInSnapshot?

  private var hasResumed = false

  /// Whether this process is flying the run itself or waiting for its window to open.
  private var isRunHeldHere: Bool { runTask != nil || startTask != nil }

  private init() {}

  /// Whether a run on `target` is still worth flying at `now`.
  ///
  /// A target with no time-on-target is never live: it has no run to be partway through, and
  /// nothing to bound one by.
  static func isRunLive(_ target: Target, at now: Date) -> Bool {
    guard let timeOnTarget = target.timeOnTarget else { return false }
    return now >= timeOnTarget - maxLead && !target.hasRunExpired(at: now)
  }

  private static func flownTarget(id: String, in container: ModelContainer) -> Target? {
    var descriptor = FetchDescriptor<Target>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return try? container.mainContext.fetch(descriptor).first
  }

  /// Picks up a run the last process left outstanding and keeps flying it with no screen, or takes
  /// it down when it is no longer one worth flying.
  ///
  /// Belongs at `@main`, before any view exists, because on the launch this is for none ever will.
  /// It makes no assumption about whether it runs before or after the launch delegate rejoins the
  /// background session — that order is undocumented, and both converge: ending the run clears the
  /// record, so a rejoin that follows raises no session, and one that came first is torn down
  /// here.
  func resumeRunInProgress(in container: ModelContainer) {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests, !hasResumed else { return }
    hasResumed = true

    guard let targetID = BackgroundActivityHolder.shared.runTargetID,
      let target = Self.flownTarget(id: targetID, in: container),
      Self.isRunLive(target, at: Date())
    else {
      endUnclaimedRun()
      return
    }

    lastPushed = nil
    runTask = Task { [weak self] in await self?.fly(target) }
    armExpiry(for: target)
  }

  /// Raises everything the run on screen holds — the screen stays awake, the location stream
  /// survives the app ceasing to be frontmost, and the countdown appears on the Lock Screen and on
  /// the watch — and bounds it at both ends. A run whose window has not opened yet raises nothing
  /// and waits for it.
  ///
  /// Steps the screenless solver aside as it goes — the screen pushes its own figures from the first
  /// fix it draws, so the handover leaves no gap, and two solvers reading two fixes would let the
  /// Lock Screen and the CDI disagree.
  func beginRun(flying target: Target) {
    stopSolving()
    cancelStart()
    cancelExpiry()

    // A brief may be hours from the run it plans. Holding the screen awake and the aircraft's GPS
    // running through all of it is the same waste the expiry exists to stop, at the other end of
    // the run — so the screen waits at the near edge of the window rather than opening it early.
    // The run before it goes down here rather than at its own expiry: with the screen moved on,
    // there is nothing left holding it.
    guard Self.isRunLive(target, at: Date()) else {
      releaseHeldRun()
      armStart(for: target)
      return
    }

    raiseRun(flying: target)
    armExpiry(for: target)
  }

  /// Releases everything the run holds, wherever it was being flown from, and lets go of a window
  /// this process was still waiting on.
  func endRun() {
    stopSolving()
    cancelStart()
    cancelExpiry()
    releaseHeldRun()
  }

  /// Releases a run nothing in this process is flying: the wreckage a force-quit or a crash left
  /// behind, or a session `@main` rejoined for a run that was already over.
  ///
  /// A departing process gets no chance to take down its own Lock Screen countdown or clear the
  /// watch face, so this is where that happens — the holder's own session is the least of what such
  /// a run leaves standing.
  ///
  /// Unclaimed is not on its own abandoned, and the claim alone cannot tell the two apart. Two runs
  /// this process is flying hold no claim: one whose window has not opened has nothing yet to claim,
  /// and the screenless solver deliberately takes none so that the Fly screen can take the run over
  /// without a handover gap. Every foregrounding reaches here, so ending either would leave the
  /// pilot mid-sortie with a run nothing would raise again.
  func endUnclaimedRun() {
    guard !isRunHeldHere, !BackgroundActivityHolder.shared.isRunClaimed else { return }
    endRun()
  }

  /// Whether the run `target`'s screen began is still the one this process holds — raised, or
  /// waiting for its window to open.
  ///
  /// Flying straight on to the next target replaces the whole Fly screen, and SwiftUI may raise the
  /// replacement before it lowers the screen it replaces, so the departing screen asks this before
  /// dismantling anything. A pending start answers for itself: `BackgroundActivityHolder` records
  /// only runs that were raised, and reads a window still being waited on as nobody's.
  func ownsRun(flying target: Target) -> Bool {
    if let pendingStartTargetID { return pendingStartTargetID == target.id }
    return BackgroundActivityHolder.shared.ownsRun(flying: target.id)
  }

  private func fly(_ target: Target) async {
    await LocationStreamer.shared.start()
    defer { Task { await LocationStreamer.shared.stop() } }

    guard let stream = await LocationStreamer.shared.eventStream() else { return }

    do {
      for try await event in stream {
        guard !Task.isCancelled else { return }
        push(event, for: target)
      }
    } catch {
      // A stream that has failed has no further fixes to fly. The run is still bounded by its
      // expiry, which ends it whether or not fixes ever resume.
    }
  }

  /// Solves one fix and pushes the run-in figures, applying the same accuracy gate the Fly screen
  /// applies before it draws. A deliberately coarsened position is worse than none: taken at face
  /// value it would put a run-in on the Lock Screen that the aircraft is not flying.
  private func push(_ event: LocationEvent, for target: Target) {
    guard event.diagnostics.impediment == nil,
      let location = event.location,
      let math = IPTargetMath(location: location, target: target, now: Date()),
      let runIn = RunInSnapshot(math: math),
      runIn != lastPushed
    else { return }

    lastPushed = runIn
    LiveActivityController.shared.update(runIn: runIn, for: target)
  }

  /// Raises everything a live run holds. Separated from ``beginRun(flying:)`` so the decision of
  /// *whether* the run is one to raise reads apart from the raising.
  ///
  /// Replaces the previous run's holdings in place rather than releasing them first: the watch and
  /// the Live Activity are each told what is being flown now, and saying "nothing" in between would
  /// spend a metered transfer and dismiss a Lock Screen countdown only to request it again.
  private func raiseRun(flying target: Target) {
    UIApplication.shared.isIdleTimerDisabled = true
    BackgroundActivityHolder.shared.begin(targetID: target.id)
    WatchSessionController.shared.update(flying: target)
    LiveActivityController.shared.update(flying: target)
  }

  /// Releases everything a raised run holds: the screen awake, the background session and the
  /// stream it keeps alive, and the countdown on the Lock Screen and on the watch face.
  ///
  /// Stops at the screen when no run is outstanding. A screen that leaves after the run has already
  /// expired would otherwise say "no run" a second time, and the watch pays for that in a transfer
  /// budget the system meters.
  ///
  /// The screen is let go of ahead of that guard, and unconditionally: a run raised under previews
  /// or tests pins the screen awake while `BackgroundActivityHolder` records nothing, so a guarded
  /// release would leave the phone never auto-locking.
  private func releaseHeldRun() {
    UIApplication.shared.isIdleTimerDisabled = false

    guard BackgroundActivityHolder.shared.isRunOutstanding else { return }
    BackgroundActivityHolder.shared.end()
    WatchSessionController.shared.update(flying: nil)
    LiveActivityController.shared.update(flying: nil)
  }

  /// Waits at the near edge of the run's window and begins the run there. A target with no
  /// time-on-target has no window, and one whose window has already opened or closed has none left
  /// to wait for.
  ///
  /// Re-enters ``beginRun(flying:)`` rather than raising the run directly, so the window is judged
  /// again on arrival: a process suspended across the edge wakes to a decision it makes then rather
  /// than one it made hours earlier.
  private func armStart(for target: Target) {
    guard let timeOnTarget = target.timeOnTarget else { return }
    let remaining = (timeOnTarget - Self.maxLead).timeIntervalSinceNow
    guard remaining > 0 else { return }

    pendingStartTargetID = target.id
    startTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(remaining))
      guard !Task.isCancelled else { return }
      self?.beginRun(flying: target)
    }
  }

  /// Schedules the end of the run for its expiry. A target with no time-on-target has no run to
  /// bound — and none to fly, so nothing reaches here holding one.
  private func armExpiry(for target: Target) {
    cancelExpiry()
    guard let runExpiry = target.runExpiry else { return }
    let remaining = runExpiry.timeIntervalSinceNow

    expiryTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(max(remaining, 0)))
      guard !Task.isCancelled else { return }
      self?.endRun()
    }
  }

  /// Stops solving the run with no screen. Kept apart from ``cancelExpiry()``: the solver and the
  /// bound have different lifetimes — a screen taking the run over stands the solver down and keeps
  /// the bound — and one method doing both is what let the Fly screen cancel the only bound the run
  /// had.
  private func stopSolving() {
    runTask?.cancel()
    runTask = nil
    lastPushed = nil
  }

  private func cancelStart() {
    startTask?.cancel()
    startTask = nil
    pendingStartTargetID = nil
  }

  private func cancelExpiry() {
    expiryTask?.cancel()
    expiryTask = nil
  }
}
