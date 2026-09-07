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
      // Judged against the entry's own moment rather than the clock: WidgetKit renders an entry
      // whenever it likes, and a run drawn for a time it is not yet at would be drawn closing.
      if target.hasPassedTOT(at: entry.date) {
        PastTOT(target: target, family: family)
      } else if target.isClosing(at: entry.date) {
        RunInCountdown(
          target: target,
          timeOnTarget: timeOnTarget,
          family: family
        )
      } else {
        StandingOff(
          target: target,
          timeOnTarget: timeOnTarget,
          family: family
        )
      }
    } else {
      NoRun(family: family)
    }
  }
}

/// The run while it is still distant: the briefed time on target, held still.
///
/// A ticking countdown is what the pilot wants inside the run-in and is worth nothing outside it —
/// the ring is pinned full for the whole of a long wait, and the digits change too slowly to read as
/// motion, so an hour out looks very like five minutes out. A briefed time reads as what it is at any
/// range, is the number the pilot briefed against, and cannot outgrow the space it is drawn in the
/// way an hours-long countdown does.
private struct StandingOff: View {
  var target: TargetSnapshot
  var timeOnTarget: Date

  var family: WidgetFamily

  /// Zulu, with no toggle to local. The phone offers the choice and the watch face has no room to
  /// show which answer it took, and a time on target that might be either is worse than one that is
  /// always the briefing's own.
  private var briefedTime: String { timeOnTarget.formatted(zuluTOTFormatStyle) }

  private var spokenTime: Text {
    Text("Time on target \(timeOnTarget, format: localTOTFormatStyle)")
  }

  var body: some View {
    switch family {
      case .accessoryInline:
        Text(verbatim: "\(target.name) \(briefedTime)")

      case .accessoryCorner:
        Image(systemName: "clock")
          .accessibilityLabel(spokenTime)
          .widgetLabel { Text(verbatim: briefedTime) }

      case .accessoryCircular:
        // Static text, so it scales to the circle it is masked into rather than clipping the way a
        // self-updating countdown does.
        Text(verbatim: briefedTime)
          .font(.system(.body, design: .rounded).weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .accessibilityLabel(spokenTime)

      default:
        VStack(alignment: .leading, spacing: 2) {
          Text(target.name)
            .font(.caption)
            .fontWeight(.light)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text(verbatim: briefedTime)
            .font(.system(.title2, design: .rounded).weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityLabel(spokenTime)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
  /// rather than composed alongside it. The face draws that run in its own font and tint, so there
  /// is nothing to gain by styling either half.
  private var inlineCountdown: Text {
    TOTCountdownText.text(timeOnTarget: timeOnTarget)
  }

  var body: some View {
    switch family {
      case .accessoryCircular:
        // The roomiest of the ring families, so the countdown goes inside it rather than leaving
        // the pilot to read progress off the arc alone.
        TOTProgressRing(
          timeOnTarget: timeOnTarget,
          legDuration: legDuration,
          showsCountdown: true
        )

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

/// The run once its time on target has gone by, until the run expires.
///
/// A countdown clamped to zero is the one thing this must not look like. Held at `0:00` inside a ring
/// that has stopped moving, a run already flown is drawn exactly as one a second from arriving — and
/// those two ask the pilot for opposite things. So the ring goes and the words say which it is.
private struct PastTOT: View {
  var target: TargetSnapshot

  var family: WidgetFamily

  var body: some View {
    switch family {
      case .accessoryInline:
        Text("\(target.name) past TOT")

      case .accessoryCorner:
        Image(systemName: "flag.checkered")
          .accessibilityLabel(Text("Past time on target"))
          .widgetLabel { Text("Past TOT") }

      case .accessoryCircular:
        // Wraps to the two lines the circle has room for rather than shrinking to one unreadable
        // one, and carries the same words the Fly screen and the post-pass summary use.
        Text("Past TOT")
          .font(.caption)
          .fontWeight(.semibold)
          .multilineTextAlignment(.center)
          .lineLimit(2)
          .minimumScaleFactor(0.6)

      default:
        VStack(alignment: .leading, spacing: 2) {
          Text(target.name)
            .font(.caption)
            .fontWeight(.light)
            .foregroundStyle(.secondary)
            .lineLimit(1)
          Text("Past TOT")
            .font(.system(.title2, design: .rounded).weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
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
  fileprivate static var wellPastTOT: Self { .init(date: .now, target: .preview(inMinutes: -8)) }
  fileprivate static var noRun: Self { .init(date: .now, target: nil) }
}

#Preview("Rectangular", as: .accessoryRectangular) {
  TOTComplication()
} timeline: {
  TOTEntry.runIn
  TOTEntry.distant
  TOTEntry.pastTOT
  TOTEntry.wellPastTOT
  TOTEntry.noRun
}

#Preview("Circular", as: .accessoryCircular) {
  TOTComplication()
} timeline: {
  TOTEntry.runIn
  TOTEntry.distant
  TOTEntry.pastTOT
  TOTEntry.wellPastTOT
  TOTEntry.noRun
}

#Preview("Corner", as: .accessoryCorner) {
  TOTComplication()
} timeline: {
  TOTEntry.runIn
  TOTEntry.distant
  TOTEntry.pastTOT
  TOTEntry.wellPastTOT
  TOTEntry.noRun
}

#Preview("Inline", as: .accessoryInline) {
  TOTComplication()
} timeline: {
  TOTEntry.runIn
  TOTEntry.distant
  TOTEntry.pastTOT
  TOTEntry.wellPastTOT
  TOTEntry.noRun
}
