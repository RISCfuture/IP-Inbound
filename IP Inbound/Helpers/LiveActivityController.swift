import ActivityKit
import Foundation
import IP_Inbound_Shared

/// The Lock Screen / Dynamic Island counterpart to ``WatchSessionController``: starts a
/// Time-On-Target Live Activity when the pilot begins flying a target and ends it when they leave the
/// Fly screen. The countdown is self-updating — the planned TOT is handed to the system once and ticks
/// down on its own — so no background updates are needed.
@MainActor
final class LiveActivityController {
  static let shared = LiveActivityController()

  private init() {}

  /// Starts — or updates, if one is already running — the Live Activity for the target the pilot is
  /// flying, or ends it when `target` is `nil`. No-ops when Live Activities are unavailable or
  /// disabled, or under previews and tests.
  func update(flying target: Target?) {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests,
      ActivityAuthorizationInfo().areActivitiesEnabled
    else { return }

    guard let target, let timeOnTarget = target.timeOnTarget else {
      endActivities()
      return
    }

    let content = ActivityContent(
      state: TOTActivityAttributes.ContentState(timeOnTarget: timeOnTarget),
      staleDate: timeOnTarget
    )

    if Activity<TOTActivityAttributes>.activities.isEmpty {
      _ = try? Activity.request(
        attributes: TOTActivityAttributes(
          targetName: target.name,
          ipToTargetDuration: target.offsetTimeMeasurement
        ),
        content: content,
        pushType: nil
      )
    } else {
      Task {
        for activity in Activity<TOTActivityAttributes>.activities {
          await activity.update(content)
        }
      }
    }
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

    Task {
      for activity in Activity<TOTActivityAttributes>.activities {
        await activity.update(content)
      }
    }
  }

  private func endActivities() {
    Task {
      for activity in Activity<TOTActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
  }
}
