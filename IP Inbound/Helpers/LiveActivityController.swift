import ActivityKit
import Foundation
import IP_Inbound_Shared

/// The Lock Screen / Dynamic Island counterpart to ``WatchSessionController``: starts a
/// Time-On-Target Live Activity when the pilot begins flying a target and ends it when the run is
/// over. The countdown is self-updating — the planned TOT is handed to the system once and ticks
/// down on its own — so no background updates are needed.
@MainActor
final class LiveActivityController {
  static let shared = LiveActivityController()

  /// The activity work already queued.
  ///
  /// ActivityKit's start and end are both asynchronous, and a run can end and begin again in the
  /// same moment — a launch that clears the wreckage of a force-quit and then reopens the Fly
  /// screen, or a pass flown straight on to the next target. Run in whatever order the scheduler
  /// chose, a start that overtook the end before it would find an activity still standing, update
  /// that one, and then watch the end take it away, leaving a live run with nothing to draw on. One
  /// chain makes them happen in the order they were asked for.
  private var work: Task<Void, Never>?

  private init() {}

  /// Starts — or updates, if one is already running — the Live Activity for the target the pilot is
  /// flying, or ends it when `target` is `nil`. No-ops when Live Activities are unavailable or
  /// disabled, or under previews and tests.
  func update(flying target: Target?) {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests,
      ActivityAuthorizationInfo().areActivitiesEnabled
    else { return }

    guard let target, let timeOnTarget = target.timeOnTarget else {
      enqueue { await self.endActivities() }
      return
    }

    let attributes = TOTActivityAttributes(
      targetName: target.name,
      ipToTargetDuration: target.offsetTimeMeasurement
    )
    let content = ActivityContent(
      state: TOTActivityAttributes.ContentState(timeOnTarget: timeOnTarget),
      staleDate: timeOnTarget
    )

    enqueue { await self.startOrUpdate(attributes: attributes, content: content) }
  }

  /// Pushes the live run-in figures onto a running activity, leaving the countdown alone.
  ///
  /// Fixes arrive at roughly 1 Hz, which is far more often than a Lock Screen readout can usefully
  /// change; callers pass values already quantized to the precision they display, so this is only
  /// reached when the pilot would actually see a difference.
  func update(runIn: RunInSnapshot?, for target: Target) {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests,
      let timeOnTarget = target.timeOnTarget
    else { return }

    let content = ActivityContent(
      state: TOTActivityAttributes.ContentState(
        timeOnTarget: timeOnTarget,
        ipDeltaTime: runIn?.ipDeltaTime,
        distanceToIP: runIn?.distanceToIP
      ),
      staleDate: timeOnTarget
    )

    enqueue { await self.updateActivities(content) }
  }

  private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
    let previous = work
    work = Task { @MainActor in
      await previous?.value
      await operation()
    }
  }

  /// Brings the running activity into line with the target being flown, requesting one when none
  /// stands for it.
  ///
  /// Only the content state can be updated once an activity is running: the target's name and the
  /// extent of its progress ring are fixed when it is requested. So one drawn for another target
  /// cannot be made to stand for this one — it would keep that target's name and run-in leg while
  /// counting down to this target's time. It is ended and replaced instead.
  ///
  /// The collection is read here rather than at the call site because an end still waiting its turn
  /// in the queue has not taken its activity down yet, and a start that judged the collection before
  /// it ran would update the very activity the end is about to remove.
  private func startOrUpdate(
    attributes: TOTActivityAttributes,
    content: ActivityContent<TOTActivityAttributes.ContentState>
  ) async {
    let isDrawnForThisTarget = Activity<TOTActivityAttributes>.activities
      .contains { $0.attributes == attributes }

    guard isDrawnForThisTarget else {
      await endActivities()
      _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
      return
    }

    // Ending before every request leaves at most one activity standing, so the one this updates is
    // the one the guard just found.
    await updateActivities(content)
  }

  private func endActivities() async {
    for activity in Activity<TOTActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

  private func updateActivities(
    _ content: ActivityContent<TOTActivityAttributes.ContentState>
  ) async {
    for activity in Activity<TOTActivityAttributes>.activities {
      await activity.update(content)
    }
  }
}
