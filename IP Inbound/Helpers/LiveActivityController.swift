import ActivityKit
import Foundation

/// The Lock Screen / Dynamic Island counterpart to ``WatchSessionController``: starts a
/// Time-On-Target Live Activity when the pilot begins flying a target and ends it when they leave the
/// Fly screen. The countdown is self-updating — the planned TOT is handed to the system once and ticks
/// down on its own — so no background updates are needed.
@MainActor
final class LiveActivityController {
  static let shared = LiveActivityController()

  private static var isRunningPreviewsOrTests: Bool {
    let info = ProcessInfo.processInfo
    return info.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
      || info.isRunningUITests
      || NSClassFromString("XCTestCase") != nil
  }

  private init() {}

  /// Starts — or updates, if one is already running — the Live Activity for the target the pilot is
  /// flying, or ends it when `target` is `nil`. No-ops when Live Activities are unavailable or
  /// disabled, or under previews and tests.
  func update(flying target: Target?) {
    guard !Self.isRunningPreviewsOrTests,
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
      let ipToTargetDuration = Measurement(value: target.offsetTime, unit: UnitDuration.minutes)
        .converted(to: .seconds).value
      _ = try? Activity.request(
        attributes: TOTActivityAttributes(
          targetName: target.name,
          ipToTargetDuration: ipToTargetDuration
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

  private func endActivities() {
    Task {
      for activity in Activity<TOTActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
    }
  }
}
