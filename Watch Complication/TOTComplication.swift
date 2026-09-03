import IP_Inbound_Shared
import MeasurementKit
import MeasurementKitLocation
import SwiftUI
import WidgetKit

/// The watch-face complication: how long until the time on target for the run the pilot is flying.
///
/// The countdown already exists inside the watch app, but seeing it there costs a wrist raise, a tap
/// and a wait for the phone's target to arrive — and it is gone again the moment the app stops being
/// frontmost. On the face it costs nothing.
struct TOTComplication: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: WatchComplicationStore.kind,
      provider: TOTComplicationProvider()
    ) { entry in
      TOTComplicationView(target: entry.target)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Time on Target")
    .description("Counts down to the time on target for the run you're flying.")
    .supportedFamilies([
      .accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline
    ])
  }
}

/// Draws the countdown in whichever shape the face gave it, and says so plainly when there is no run
/// to count down to.
private struct TOTComplicationView: View {
  var target: TargetSnapshot?

  @Environment(\.widgetFamily)
  private var family

  var body: some View {
    if let target, let timeOnTarget = target.timeOnTarget {
      RunInCountdown(target: target, timeOnTarget: timeOnTarget, family: family)
    } else {
      NoRun(family: family)
    }
  }
}

private struct RunInCountdown: View {
  var target: TargetSnapshot
  var timeOnTarget: Date
  var family: WidgetFamily

  /// How much of the ring is drawn: the run-in leg, the same extent the Live Activity uses.
  private var legDuration: Measurement<UnitDuration> {
    target.IPToTarget.length / target.targetGroundSpeedMeasurement
  }

  /// The inline family renders a single run of text, so the countdown is interpolated into it
  /// rather than composed alongside it.
  private var inlineCountdown: Text {
    Text(
      .currentDate,
      format: .timer(countingDownIn: Date.now..<timeOnTarget, maxPrecision: .seconds(1))
    )
  }

  var body: some View {
    switch family {
      case .accessoryCircular:
        TOTProgressRing(timeOnTarget: timeOnTarget, legDuration: legDuration)

      case .accessoryCorner:
        // The corner families draw a small graphic against the bezel; the countdown itself belongs
        // in the widget label, which is the only text the corner shows.
        TOTProgressRing(timeOnTarget: timeOnTarget, legDuration: legDuration)
          .widgetLabel {
            TOTCountdownText(timeOnTarget: timeOnTarget, font: .caption)
          }

      case .accessoryInline:
        Text("\(target.name) \(inlineCountdown)")

      default:
        VStack(alignment: .leading, spacing: 0) {
          Text(target.name)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          TOTCountdownText(
            timeOnTarget: timeOnTarget,
            font: .system(.title2, design: .rounded).weight(.semibold)
          )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct NoRun: View {
  var family: WidgetFamily

  var body: some View {
    switch family {
      case .accessoryInline:
        Text("No run")
      case .accessoryCorner:
        Image(systemName: "scope")
          .accessibilityLabel("No run")
          .widgetLabel { Text("No run") }
      default:
        Image(systemName: "scope")
          .accessibilityLabel("No run")
          .foregroundStyle(.secondary)
    }
  }
}
