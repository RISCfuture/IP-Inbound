import Foundation
import SwiftUI

/// The whole of what a wrist has room for: which target, and how long until its time on target.
///
/// Both the watch-face complication and the Live Activity mirrored to the watch show this, so the two
/// cannot drift into disagreeing about a run the pilot is flying. The target is named quietly because
/// the pilot already knows which one they briefed; the countdown is the thing the wrist was raised
/// for, and reads accordingly.
public struct TOTGlance: View {
  /// The name of the target being run in on.
  public var targetName: String

  /// The briefed time on target, or `nil` when none is set.
  public var timeOnTarget: Date?

  public var body: some View {
    VStack(spacing: 2) {
      Text(targetName)
        .font(.caption)
        .fontWeight(.light)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      TOTCountdownText(
        timeOnTarget: timeOnTarget,
        font: .system(.title2, design: .rounded).weight(.bold),
        pastTOTFont: .system(.headline, design: .rounded).weight(.bold)
      )
      Text("to TOT", bundle: .guidance)
        .font(.caption2)
        .textCase(.uppercase)
        .foregroundStyle(.secondary)
    }
    .multilineTextAlignment(.center)
    .frame(maxWidth: .infinity)
  }

  public init(targetName: String, timeOnTarget: Date?) {
    self.targetName = targetName
    self.timeOnTarget = timeOnTarget
  }
}

// Previewable here and not in the Live Activity, because a widget extension can host only widget
// previews — and no `ActivityPreviewViewKind` renders the watch.
#Preview("Counting down", traits: .fixedLayout(width: 180, height: 90)) {
  TOTGlance(targetName: "Bullseye", timeOnTarget: .now.addingTimeInterval(140))
    .background(.black)
}

#Preview("Past TOT", traits: .fixedLayout(width: 180, height: 90)) {
  TOTGlance(targetName: "Bullseye", timeOnTarget: .now.addingTimeInterval(-30))
    .background(.black)
}

#Preview("Long name", traits: .fixedLayout(width: 180, height: 90)) {
  TOTGlance(targetName: "Nellis Range Bullseye 42", timeOnTarget: .now.addingTimeInterval(3_600))
    .background(.black)
}
