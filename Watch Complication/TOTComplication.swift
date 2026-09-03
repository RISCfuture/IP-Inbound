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
    TOTCountdownText.text(timeOnTarget: timeOnTarget)
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
        // One run, unstyled: watchOS draws the inline family in the face's own font, so weights set
        // here are dropped. The countdown is still interpolated rather than concatenated, because
        // `Text` + `Text` is deprecated.
        Text("\(Text(target.name)) \(inlineCountdown)")

      default:
        VStack(alignment: .leading, spacing: 2) {
          Text(target.name)
            .font(.caption)
            .fontWeight(.light)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          TOTCountdownText(
            timeOnTarget: timeOnTarget,
            font: .system(.title2, design: .rounded).weight(.bold)
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

extension TargetSnapshot {
  /// A briefed run for the previews: a four-mile run-in at 120 knots, two minutes out.
  fileprivate static func preview(inMinutes minutes: Double) -> Self {
    .init(
      id: "preview",
      name: "Bullseye",
      latitude: 36.772367,
      longitude: -115.453840,
      offsetBearing: 180,
      offsetBearingIsTrue: true,
      offsetDistance: 4,
      targetGroundSpeed: 120,
      timeOnTarget: .now.addingTimeInterval(minutes * 60),
      declination: 0
    )
  }
}

extension TOTEntry {
  fileprivate static var runIn: Self { .init(date: .now, target: .preview(inMinutes: 2)) }
  fileprivate static var distant: Self { .init(date: .now, target: .preview(inMinutes: 47)) }
  fileprivate static var pastTOT: Self { .init(date: .now, target: .preview(inMinutes: -1)) }
  fileprivate static var noRun: Self { .init(date: .now, target: nil) }
}

#Preview("Rectangular", as: .accessoryRectangular) {
  TOTComplication()
} timeline: {
  TOTEntry.runIn
  TOTEntry.distant
  TOTEntry.pastTOT
  TOTEntry.noRun
}

#Preview("Circular", as: .accessoryCircular) {
  TOTComplication()
} timeline: {
  TOTEntry.runIn
  TOTEntry.noRun
}

#Preview("Corner", as: .accessoryCorner) {
  TOTComplication()
} timeline: {
  TOTEntry.runIn
  TOTEntry.noRun
}

#Preview("Inline", as: .accessoryInline) {
  TOTComplication()
} timeline: {
  TOTEntry.runIn
  TOTEntry.pastTOT
  TOTEntry.noRun
}
