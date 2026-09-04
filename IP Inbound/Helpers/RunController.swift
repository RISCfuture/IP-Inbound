import CoreLocation
import Foundation
import IP_Inbound_Shared
import MeasurementKit
import SwiftData

/// Flies the run when there is no screen to fly it.
///
/// The guidance the pilot reads is solved in `FlyView`'s body, which is the right place for it while
/// there is a body to solve it in. There is not always: Core Location relaunches the app in the
/// background when a run outlives the process, and that launch connects no scene, so no view is ever
/// built. Left at that, the run-in figures on the Lock Screen freeze at whatever they read when the
/// process died, and stay frozen until the pilot next looks at the phone.
///
/// So this drives the same figures from the same stream with nothing on screen, and steps aside the
/// moment the Fly screen appears — ``handOverToScreen()`` — because two solvers reading two fixes
/// would let the Lock Screen and the CDI disagree. It does not re-request the Live Activity: starting
/// one is foreground-only, so a run whose activity did not survive the relaunch has nowhere to draw
/// and this quietly pushes into an empty collection.
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

  /// How long past the planned time-on-target an unattended run keeps flying before it is abandoned.
  /// A run nobody is watching has to stop on its own, or a relaunch begets a relaunch forever.
  private static let grace = Measurement(value: 5, unit: UnitDuration.minutes)

  private var runTask: Task<Void, Never>?
  private var deadlineTask: Task<Void, Never>?

  /// The last figures pushed, so a fix that would not move the Lock Screen's readout is not sent.
  /// `RunInSnapshot` is already rounded to the precision it displays at.
  private var lastPushed: RunInSnapshot?

  private var hasResumed = false

  private init() {}

  /// Whether a run on `target` is still worth flying at `now`.
  ///
  /// A target with no time-on-target is never live: it has no run to be partway through, and nothing
  /// to bound an unattended one by.
  static func isRunLive(_ target: Target, at now: Date) -> Bool {
    guard let timeOnTarget = target.timeOnTarget else { return false }
    return now >= timeOnTarget - maxLead && now <= timeOnTarget + grace
  }

  private static func flownTarget(id: String, in container: ModelContainer) -> Target? {
    var descriptor = FetchDescriptor<Target>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return try? container.mainContext.fetch(descriptor).first
  }

  /// Picks up a run the last process left outstanding and keeps flying it with no screen, or forgets
  /// it when it is no longer one worth flying.
  ///
  /// Belongs at `@main`, before any view exists, because on the launch this is for none ever will.
  /// It makes no assumption about whether it runs before or after the launch delegate rejoins the
  /// background session — that order is undocumented, and both converge: abandoning the run clears
  /// the record, so a rejoin that follows raises no session, and one that came first is torn down
  /// here.
  func resumeRunInProgress(in container: ModelContainer) {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests, !hasResumed else { return }
    hasResumed = true

    guard let targetID = BackgroundActivityHolder.shared.runTargetID,
      let target = Self.flownTarget(id: targetID, in: container),
      Self.isRunLive(target, at: Date())
    else {
      BackgroundActivityHolder.shared.end()
      return
    }

    lastPushed = nil
    runTask = Task { [weak self] in await self?.fly(target) }
    armDeadline(for: target)
  }

  /// Stops driving the run, leaving it running for the Fly screen that has just appeared to drive
  /// instead. The screen pushes its own figures from the first fix it draws, so the handover leaves
  /// no gap.
  func handOverToScreen() {
    stopDriving()
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
      // deadline, which ends it whether or not fixes ever resume.
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

  private func armDeadline(for target: Target) {
    guard let timeOnTarget = target.timeOnTarget else { return }
    let remaining = (timeOnTarget + Self.grace).timeIntervalSinceNow

    deadlineTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(max(remaining, 0)))
      guard !Task.isCancelled else { return }
      self?.abandonRun()
    }
  }

  /// Ends a run that has outlived its time-on-target with nobody watching it.
  private func abandonRun() {
    stopDriving()
    BackgroundActivityHolder.shared.end()
    WatchSessionController.shared.update(flying: nil)
    LiveActivityController.shared.update(flying: nil)
  }

  private func stopDriving() {
    runTask?.cancel()
    runTask = nil
    deadlineTask?.cancel()
    deadlineTask = nil
    lastPushed = nil
  }
}
