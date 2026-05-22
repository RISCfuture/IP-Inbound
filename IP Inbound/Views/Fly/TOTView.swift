import Defaults
import SwiftUI

struct TOTView: View {
  /// Display ceiling for the required-speed callout. An IP only seconds away yields an enormous
  /// required ground speed; clamping keeps the readout on-screen and away from formatter overflow.
  private static let maxRequiredGroundSpeed = Measurement(value: 999, unit: UnitSpeed.knots)

  private static let
    readoutSpacing = 6.0,
    readoutRowSpacing = 2.0,
    timeReadoutSpacing = 4.0

  var fromTo: FromToMath
  var timeOnTarget: Date?
  var showSpeed = true
  var isPush = false
  /// When set, appends the required ground speed in parentheses after the current speed, tinted
  /// with this color (the timing-tier color from ``TimingView``). `nil` hides the callout.
  var requiredSpeedColor: Color?

  @Default(.TOTDisplayMode)
  private var displayMode

  @Default(.distanceUnit)
  private var distanceDefault

  /// The required ground speed clamped to ``maxRequiredGroundSpeed`` for display. `nil` when no
  /// required speed is available.
  private var cappedRequiredGroundSpeed: Measurement<UnitSpeed>? {
    guard let requiredGroundSpeed = fromTo.requiredGroundSpeed else { return nil }
    return min(requiredGroundSpeed, Self.maxRequiredGroundSpeed)
  }

  /// Current ground speed, optionally followed by the colored required-speed callout, e.g.
  /// "120 kn (180 kn req.)".
  private var speedText: Text {
    let current = Text(
      fromTo.speed.converted(to: distanceDefault.speedUnit),
      format: speedFormatStyle
    )
    guard let requiredSpeedColor, let cappedRequiredGroundSpeed else {
      return current
    }
    let required = cappedRequiredGroundSpeed.converted(to: distanceDefault.speedUnit)
    return current
      + Text(String(localized: " (\(required, format: speedFormatStyle) req.)"))
      .foregroundStyle(requiredSpeedColor)
  }

  // Each readout (speed, distance, TOT) stays intact; the row wraps a whole readout to the next
  // line when it can't fit, and the dot separators show only between readouts on the same line.
  var body: some View {
    FlowLayout(spacing: Self.readoutSpacing, rowSpacing: Self.readoutRowSpacing) {
      if showSpeed {
        speedReadout
        dotSeparator
      }
      distanceReadout
      if let timeOnTarget {
        dotSeparator
        timeReadout(timeOnTarget)
      }
    }
    .lineLimit(1)
    .fontWeight(.bold)
  }

  private var dotSeparator: some View {
    Text("•").flowSeparator().accessibilityHidden(true)
  }

  private var speedReadout: some View {
    speedText
      .onTapGesture { cycleUnits() }
      .accessibilityAddTraits(.isButton)
      .accessibilityHint("Cycle speed units")
      .accessibilityIdentifier("flySpeedDisplay")
  }

  private var distanceReadout: some View {
    Text(fromTo.distance.converted(to: distanceDefault.distanceUnit), format: distanceFormatStyle)
      .onTapGesture { cycleUnits() }
      .accessibilityAddTraits(.isButton)
      .accessibilityHint("Cycle distance units")
      .accessibilityIdentifier("flyDistanceDisplay")
  }

  private func cycleUnits() {
    guard let index = DistanceUnit.allCases.firstIndex(of: distanceDefault) else {
      distanceDefault = .nauticalMiles
      return
    }

    let nextIndex = (index + 1) % DistanceUnit.allCases.count
    distanceDefault = DistanceUnit.allCases[nextIndex]
  }

  @ViewBuilder
  private func timeReadout(_ timeOnTarget: Date) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: Self.timeReadoutSpacing) {
      switch displayMode {
        case .local:
          Text(timeOnTarget, format: localTOTFormatStyle)
            .onTapGesture { displayMode = .zulu }
            .accessibilityHint("Toggle local or zulu time")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("flyTOTDisplay")
        case .zulu:
          Text(timeOnTarget, format: zuluTOTFormatStyle)
            .onTapGesture { displayMode = .local }
            .accessibilityHint("Toggle local or zulu time")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("flyTOTDisplay")
      }
      Text(isPush ? "Push" : "TOT")
        .font(.caption)
        .textCase(.uppercase)
    }
  }
}

#Preview("Speed • Distance • TOT") {
  let helper = PreviewHelper()
  let target = helper.target()
  let math = IPTargetMath(location: helper.preIPLocation, target: target, now: .now)

  TOTView(fromTo: math.pposToTarget!, timeOnTarget: target.timeOnTarget)
}

#Preview("With required-speed callout") {
  let helper = PreviewHelper()
  let target = helper.target()
  let math = IPTargetMath(location: helper.preIPLocation, target: target, now: .now)

  TOTView(
    fromTo: math.pposToTarget!,
    timeOnTarget: target.timeOnTarget,
    requiredSpeedColor: .red
  )
}
