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
      TOTComplicationView(entry: entry)
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
  var entry: TOTEntry

  @Environment(\.widgetFamily)
  private var family

  var body: some View {
    if let target = entry.target, let timeOnTarget = target.timeOnTarget {
      RunInCountdown(
        target: target,
        timeOnTarget: timeOnTarget,
        asOf: entry.date,
        family: family
      )
    } else {
      NoRun(family: family)
    }
  }
}

private struct RunInCountdown: View {
  var target: TargetSnapshot
  var timeOnTarget: Date

  /// The moment this drawing stands for. WidgetKit renders an entry ahead of the date it is
  /// scheduled for, so the countdown is read against that date rather than against the present —
  /// which is what lets the entry scheduled at the time on target say the time has passed.
  var asOf: Date

  var family: WidgetFamily

  /// How much of the ring is drawn: the run-in leg, the same extent the Live Activity uses.
  private var legDuration: Measurement<UnitDuration> {
    target.IPToTarget.length / target.targetGroundSpeedMeasurement
  }

  /// The inline family renders a single run of text, so the countdown is interpolated into it
  /// rather than composed alongside it. The face draws that run in its own font and tint, so there
  /// is nothing to gain by styling either half.
  private var inlineCountdown: Text {
    .totCountdown(to: timeOnTarget, asOf: asOf)
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
            TOTCountdownText(timeOnTarget: timeOnTarget, font: .caption, asOf: asOf)
          }

      case .accessoryInline:
        Text("\(target.name) \(inlineCountdown)")

      default:
        VStack(alignment: .leading, spacing: 2) {
          Text(target.name)
            .font(.caption)
            .fontWeight(.light)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          TOTCountdownText(
            timeOnTarget: timeOnTarget,
            font: .system(.title2, design: .rounded).weight(.bold),
            pastTOTFont: .system(.headline, design: .rounded).weight(.bold),
            asOf: asOf
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
  /// A briefed run for the previews: a four-mile run-in at 120 knots, with the time on target
  /// `minutes` from now — negative for a run whose TOT has already gone by.
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
  TOTEntry.distant
  TOTEntry.pastTOT
  TOTEntry.noRun
}

#Preview("Corner", as: .accessoryCorner) {
  TOTComplication()
} timeline: {
  TOTEntry.runIn
  TOTEntry.distant
  TOTEntry.pastTOT
  TOTEntry.noRun
}

#Preview("Inline", as: .accessoryInline) {
  TOTComplication()
} timeline: {
  TOTEntry.runIn
  TOTEntry.distant
  TOTEntry.pastTOT
  TOTEntry.noRun
}
