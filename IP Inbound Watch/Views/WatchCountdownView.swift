import SwiftUI

/// On-the-ground display: a live countdown to the target's time-on-target, with a reminder that
/// course guidance appears once the aircraft is moving.
struct WatchCountdownView: View {
  var target: TargetSnapshot

  @ScaledMetric(relativeTo: .headline)
  private var nameFontSize = 16.0
  @ScaledMetric(relativeTo: .caption2)
  private var countdownUnitFontSize = 13.0
  @ScaledMetric(relativeTo: .title3)
  private var pastTOTFontSize = 20.0
  @ScaledMetric(relativeTo: .footnote)
  private var helpFontSize = 14.0

  var body: some View {
    VStack {
      Text(target.name)
        .font(.system(size: nameFontSize, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.bottom)

      if let timeOnTarget = target.timeOnTarget, timeOnTarget > Date() {
        Text(
          .currentDate,
          format: .timer(countingDownIn: Date.now..<timeOnTarget, maxPrecision: .seconds(1))
        )
        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
        .contentTransition(.numericText())
        Text("to TOT")
          .font(.system(size: countdownUnitFontSize))
          .foregroundStyle(.secondary)
      } else {
        Text("Past TOT")
          .font(.system(size: pastTOTFontSize))
      }

      Text("Guidance begins once you’re moving.")
        .font(.system(size: helpFontSize))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.top)
    }
    .padding(.horizontal)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("watchCountdown")
  }
}

#Preview("Counting Down") {
  WatchCountdownView(target: WatchPreviewData.target)
}
