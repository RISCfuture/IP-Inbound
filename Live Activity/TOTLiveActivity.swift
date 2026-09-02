import ActivityKit
import MeasurementKit
import SwiftUI
import WidgetKit

/// The Lock Screen and Dynamic Island presentation of the Time-On-Target Live Activity. The countdown
/// is rendered with the same self-updating `.timer(countingDownIn:)` format the in-app
/// `CountdownTimerView` uses, so the system ticks it down without any pushed updates.
struct TOTLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TOTActivityAttributes.self) { context in
      VStack(spacing: 2) {
        Text(context.attributes.targetName)
          .font(.headline)
        TOTCountdown(timeOnTarget: context.state.timeOnTarget)
          .font(.title)
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
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 2) {
            Text(context.attributes.targetName)
              .font(.headline)
            TOTCountdown(timeOnTarget: context.state.timeOnTarget)
              .font(.title2)
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
        TOTCountdown(timeOnTarget: context.state.timeOnTarget)
      } minimal: {
        TOTProgressRing(
          timeOnTarget: context.state.timeOnTarget,
          legDuration: context.attributes.ipToTargetDuration
        )
      }
    }
  }
}

/// The countdown range, clamped to stay ascending once the planned time passes so the timer reads zero
/// (and the ring stays empty) rather than running backwards before the activity ends.
private func countdownRange(to timeOnTarget: Date) -> ClosedRange<Date> {
  .now...max(timeOnTarget, .now.addingTimeInterval(1))
}

/// The distance still to fly to the IP and how the projected crossing compares with the plan, or
/// nothing at all once the IP is behind the aircraft and only the countdown is left to show.
///
/// The extension links neither `IP Inbound Shared` nor `MeasurementKitLocation`, so the guidance math
/// runs in the app and arrives here already solved; this only formats it.
private struct RunInSummary: View {
  var state: TOTActivityAttributes.ContentState

  var body: some View {
    if let distanceToIP = state.distanceToIP, let ipDeltaTime = state.ipDeltaTime {
      Text("\(distanceToIP, format: .runInDistance) to IP · \(timing(ipDeltaTime))")
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

extension FormatStyle where Self == Measurement<UnitLength>.FormatStyle {
  /// Mirrors `distanceFormatStyle` in `IP Inbound Shared`, which the extension cannot import, so the
  /// Lock Screen renders distances exactly as the Fly screen does.
  fileprivate static var runInDistance: Self {
    .measurement(
      width: .abbreviated,
      usage: .asProvided,
      numberFormatStyle: .number.rounded(increment: 0.1)
    )
  }
}

/// A self-updating textual countdown to `timeOnTarget`.
private struct TOTCountdown: View {
  var timeOnTarget: Date

  var body: some View {
    Text(timerInterval: countdownRange(to: timeOnTarget), countsDown: true)
      .monospacedDigit()
  }
}

/// A self-updating circular countdown ring for the cramped minimal Dynamic Island, where a textual
/// countdown clips. Full extent is the IP-to-target leg: full while still inbound to the IP, emptying
/// over the final `legDuration` to TOT. The labels are suppressed so only the ring shows.
private struct TOTProgressRing: View {
  private static let minimumLegDuration = Measurement(value: 1, unit: UnitDuration.seconds)

  var timeOnTarget: Date
  var legDuration: Measurement<UnitDuration>

  private var ringRange: ClosedRange<Date> {
    let extent = max(legDuration, Self.minimumLegDuration)
    return (timeOnTarget - extent)...timeOnTarget
  }

  var body: some View {
    ProgressView(timerInterval: ringRange, countsDown: true) {
      EmptyView()
    } currentValueLabel: {
      EmptyView()
    }
    .progressViewStyle(.circular)
    .scaleEffect(1.4)
    .accessibilityLabel("Time on target countdown")
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
  fileprivate static var near: TOTActivityAttributes.ContentState {
    .init(timeOnTarget: .now.addingTimeInterval(45))
  }

  fileprivate static var far: TOTActivityAttributes.ContentState {
    .init(timeOnTarget: .now.addingTimeInterval(600))
  }
}

#Preview("Notification", as: .content, using: TOTActivityAttributes.preview) {
  TOTLiveActivity()
} contentStates: {
  TOTActivityAttributes.ContentState.near
  TOTActivityAttributes.ContentState.far
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: TOTActivityAttributes.preview) {
  TOTLiveActivity()
} contentStates: {
  TOTActivityAttributes.ContentState.near
  TOTActivityAttributes.ContentState.far
}

#Preview("Compact", as: .dynamicIsland(.compact), using: TOTActivityAttributes.preview) {
  TOTLiveActivity()
} contentStates: {
  TOTActivityAttributes.ContentState.near
  TOTActivityAttributes.ContentState.far
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: TOTActivityAttributes.preview) {
  TOTLiveActivity()
} contentStates: {
  TOTActivityAttributes.ContentState.near
  TOTActivityAttributes.ContentState.far
}
