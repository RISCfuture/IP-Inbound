import ActivityKit
import IP_Inbound_Shared
import MeasurementKit
import SwiftUI
import WidgetKit

/// The Lock Screen and Dynamic Island presentation of the Time-On-Target Live Activity. The countdown
/// is rendered with the same self-updating `.timer(countingDownIn:)` format the in-app
/// `CountdownTimerView` uses, so the system ticks it down without any pushed updates.
struct TOTLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TOTActivityAttributes.self) { context in
      LiveActivityContent(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 2) {
            Text(context.attributes.targetName)
              .font(.headline)
              .fontWeight(.light)
            TOTCountdownText(
              timeOnTarget: context.state.timeOnTarget,
              font: .title2.weight(.bold)
            )
            Text("to TOT")
              .font(.caption2)
              .textCase(.uppercase)
              .foregroundStyle(.secondary)
            RunInSummary(state: context.state)
              .font(.caption2)
          }
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)
        }
      } compactLeading: {
        Text(context.attributes.targetName)
          .lineLimit(1)
      } compactTrailing: {
        TOTCountdownText(timeOnTarget: context.state.timeOnTarget, font: .body)
      } minimal: {
        TOTProgressRing(
          timeOnTarget: context.state.timeOnTarget,
          legDuration: context.attributes.ipToTargetDuration
        )
        // The minimal presentation is the tightest the ring is ever drawn, so it alone needs
        // enlarging to stay readable.
        .scaleEffect(1.4)
      }
    }
    // Without this the Apple Watch renders the mirrored activity from the Dynamic Island's compact
    // regions, which sit flush against each other and share one weight — a run-in that reads as
    // "Bullseye2:20".
    .supplementalActivityFamilies([.small])
  }
}

/// The activity as the Lock Screen and the Apple Watch each want it.
///
/// The watch gets its own layout rather than the Lock Screen's: it has a fraction of the room, so the
/// run-in summary comes off and what is left is sized to be read at a glance — the target named
/// quietly, the countdown as the thing the pilot is actually looking for.
private struct LiveActivityContent: View {
  var context: ActivityViewContext<TOTActivityAttributes>

  @Environment(\.activityFamily)
  private var activityFamily

  var body: some View {
    switch activityFamily {
      case .small: watch
      default: lockScreen
    }
  }

  private var watch: some View {
    VStack(spacing: 2) {
      Text(context.attributes.targetName)
        .font(.caption)
        .fontWeight(.light)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      TOTCountdownText(
        timeOnTarget: context.state.timeOnTarget,
        font: .system(.title2, design: .rounded).weight(.bold)
      )
      Text("to TOT")
        .font(.caption2)
        .textCase(.uppercase)
        .foregroundStyle(.secondary)
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 4)
  }

  private var lockScreen: some View {
    VStack(spacing: 2) {
      Text(context.attributes.targetName)
        .font(.headline)
        .fontWeight(.light)
      TOTCountdownText(
        timeOnTarget: context.state.timeOnTarget,
        font: .title.weight(.bold)
      )
      Text("to TOT")
        .font(.caption)
        .textCase(.uppercase)
        .foregroundStyle(.secondary)
      RunInSummary(state: context.state)
        .font(.caption)
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
    .padding()
  }
}

/// The distance still to fly to the IP and how the projected crossing compares with the plan, or
/// nothing at all once the IP is behind the aircraft and only the countdown is left to show.
///
/// The guidance math runs in the app and arrives here already solved; this only formats it.
private struct RunInSummary: View {
  var state: TOTActivityAttributes.ContentState

  var body: some View {
    if let distanceToIP = state.distanceToIP, let ipDeltaTime = state.ipDeltaTime {
      Text("\(distanceToIP, format: distanceFormatStyle) to IP · \(timing(ipDeltaTime))")
        .foregroundStyle(.secondary)
    }
  }

  /// Reads the signed delta as plain English, so "1:20 early" needs no sign convention to decode.
  /// The magnitude is a clock figure rather than a count of seconds, matching the countdown above it
  /// and staying readable once the delta runs past a minute. The rounding the app applies means
  /// values near zero really are on time rather than merely small.
  private func timing(_ ipDeltaTime: Measurement<UnitDuration>) -> String {
    let seconds = ipDeltaTime.converted(to: .seconds).value
    guard abs(seconds) >= 1 else { return String(localized: "on time") }
    let magnitude = Duration.seconds(abs(seconds)).formatted(
      .time(pattern: .minuteSecond(padMinuteToLength: 1))
    )
    return seconds < 0
      ? String(localized: "\(magnitude) early")
      : String(localized: "\(magnitude) late")
  }
}

extension TOTActivityAttributes {
  fileprivate static var preview: TOTActivityAttributes {
    TOTActivityAttributes(
      targetName: "Bullseye",
      ipToTargetDuration: .init(value: 120, unit: .seconds)
    )
  }
}

extension TOTActivityAttributes.ContentState {
  /// Still short of the IP and running early, which is what puts the run-in summary on screen.
  fileprivate static var early: TOTActivityAttributes.ContentState {
    runIn(ipDeltaSeconds: -80, distanceToIP: 12)
  }

  /// Late enough to read as a clock figure rather than a count of seconds.
  fileprivate static var late: TOTActivityAttributes.ContentState {
    runIn(ipDeltaSeconds: 95, distanceToIP: 9)
  }

  /// Inside the sub-second band the app rounds to, where the summary says so in words.
  fileprivate static var onTime: TOTActivityAttributes.ContentState {
    runIn(ipDeltaSeconds: 0.4, distanceToIP: 7)
  }

  /// The IP is behind the aircraft, so the summary drops away and only the countdown is left.
  fileprivate static var finalRun: TOTActivityAttributes.ContentState {
    .init(timeOnTarget: .now.addingTimeInterval(45))
  }

  private static func runIn(
    ipDeltaSeconds: Double,
    distanceToIP: Double
  ) -> TOTActivityAttributes.ContentState {
    .init(
      timeOnTarget: .now.addingTimeInterval(600),
      ipDeltaTime: .init(value: ipDeltaSeconds, unit: .seconds),
      distanceToIP: .init(value: distanceToIP, unit: .nauticalMiles)
    )
  }
}

#Preview("Notification", as: .content, using: TOTActivityAttributes.preview) {
  TOTLiveActivity()
} contentStates: {
  TOTActivityAttributes.ContentState.early
  TOTActivityAttributes.ContentState.late
  TOTActivityAttributes.ContentState.onTime
  TOTActivityAttributes.ContentState.finalRun
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: TOTActivityAttributes.preview) {
  TOTLiveActivity()
} contentStates: {
  TOTActivityAttributes.ContentState.early
  TOTActivityAttributes.ContentState.late
  TOTActivityAttributes.ContentState.onTime
  TOTActivityAttributes.ContentState.finalRun
}

#Preview("Compact", as: .dynamicIsland(.compact), using: TOTActivityAttributes.preview) {
  TOTLiveActivity()
} contentStates: {
  TOTActivityAttributes.ContentState.early
  TOTActivityAttributes.ContentState.finalRun
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: TOTActivityAttributes.preview) {
  TOTLiveActivity()
} contentStates: {
  TOTActivityAttributes.ContentState.early
  TOTActivityAttributes.ContentState.finalRun
}
