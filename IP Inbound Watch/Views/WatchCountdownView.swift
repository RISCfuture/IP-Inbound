import IP_Inbound_Shared
import SwiftUI

/// The display for every phase with no run-in to steer: a live countdown to the target's
/// time-on-target, under a line saying why there is no course guidance to show alongside it.
struct WatchCountdownView: View {
  var target: TargetSnapshot

  /// The phase the countdown is standing in for, which is what the explanatory line answers to.
  var guidance: Guidance

  @ScaledMetric(relativeTo: .headline)
  private var nameFontSize = 16.0
  @ScaledMetric(relativeTo: .caption2)
  private var countdownUnitFontSize = 13.0
  @ScaledMetric(relativeTo: .footnote)
  private var helpFontSize = 14.0

  var body: some View {
    VStack {
      Text(target.name)
        .font(.system(size: nameFontSize, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.bottom)

      if let timeOnTarget = target.timeOnTarget {
        TOTCountdownText(
          timeOnTarget: timeOnTarget,
          font: .system(.largeTitle, design: .rounded).weight(.semibold)
        )
        Text("to TOT")
          .font(.system(size: countdownUnitFontSize))
          .foregroundStyle(.secondary)
      }

      Text(explanation)
        .font(.system(size: helpFontSize))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.top)
    }
    .padding(.horizontal)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("watchCountdown")
  }

  /// Why the screen is a countdown rather than a course: the run has not started, or it is over.
  private var explanation: LocalizedStringKey {
    switch guidance {
      case .postPass: "This pass is flown."
      case .countdownOnly, .toIPWithSpeedGuidance, .toIPWithCountdown, .toTarget,
        .toTargetBypassingIP:
        "Guidance begins once you’re moving."
    }
  }
}

#Preview("Counting Down") {
  WatchCountdownView(target: WatchPreviewData.target, guidance: .countdownOnly)
}

#Preview("Pass Flown") {
  WatchCountdownView(target: WatchPreviewData.target, guidance: .postPass)
}
