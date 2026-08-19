import Defaults
import MeasurementKitLocation
import SwiftUI

/// The one-line run-in readout: ground speed (with an optional required-speed callout), distance to
/// go, and the time to make. Each element is driven by the value it shows, so a stationary fix — one
/// with no ground speed to report — still gets its distance and time.
struct TOTView: View {
  /// Display ceiling for the required-speed callout. An IP only seconds away yields an enormous
  /// required ground speed; clamping keeps the readout on-screen and away from formatter overflow.
  private static let maxRequiredGroundSpeed = Measurement(value: 999, unit: UnitSpeed.knots)

  private static let
    readoutSpacing = 6.0,
    readoutRowSpacing = 2.0,
    timeReadoutSpacing = 4.0

  /// How far there is left to fly.
  var distance: Measurement<UnitLength>
  /// Present ground speed. `nil` hides the speed readout, as when the fix reports no motion.
  var speed: Measurement<UnitSpeed>?
  /// Ground speed needed to make ``timeOnTarget``, shown as a callout after the current speed when
  /// ``requiredSpeedColor`` is set.
  var requiredGroundSpeed: Measurement<UnitSpeed>?
  var timeOnTarget: Date?
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
    guard let requiredGroundSpeed else { return nil }
    return min(requiredGroundSpeed, Self.maxRequiredGroundSpeed)
  }

  // Each readout (speed, distance, TOT) stays intact; the row wraps a whole readout to the next
  // line when it can't fit, and the dot separators show only between readouts on the same line.
  var body: some View {
    FlowLayout(spacing: Self.readoutSpacing, rowSpacing: Self.readoutRowSpacing) {
      if let speed {
        speedReadout(speed)
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

  private var distanceReadout: some View {
    Text(distance.converted(to: distanceDefault.distanceUnit), format: distanceFormatStyle)
      .onTapGesture { cycleUnits() }
      .accessibilityAddTraits(.isButton)
      .accessibilityHint("Cycle distance units")
      .accessibilityIdentifier("flyDistanceDisplay")
  }

  /// Current ground speed, optionally followed by the colored required-speed callout, e.g.
  /// "120 kn (180 kn req.)".
  private func speedText(_ speed: Measurement<UnitSpeed>) -> Text {
    let current = Text(speed.converted(to: distanceDefault.speedUnit), format: speedFormatStyle)
    guard let requiredSpeedColor, let cappedRequiredGroundSpeed else {
      return current
    }
    let required = cappedRequiredGroundSpeed.converted(to: distanceDefault.speedUnit)
    let callout = Text(String(localized: " (\(required, format: speedFormatStyle) req.)"))
      .foregroundStyle(requiredSpeedColor)
    return Text("\(current)\(callout)")
  }

  private func speedReadout(_ speed: Measurement<UnitSpeed>) -> some View {
    speedText(speed)
      .onTapGesture { cycleUnits() }
      .accessibilityAddTraits(.isButton)
      .accessibilityHint("Cycle speed units")
      .accessibilityIdentifier("flySpeedDisplay")
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

extension TOTView {
  /// The readout for a solved leg, taking its distance and both speeds from the leg's geometry.
  ///
  /// - Parameters:
  ///   - fromTo: the leg being flown.
  ///   - timeOnTarget: the time to make at the far end.
  ///   - isPush: whether that time is a push time rather than a time-on-target.
  ///   - requiredSpeedColor: tint for the required-speed callout; `nil` hides it.
  init(
    fromTo: FromToMath,
    timeOnTarget: Date?,
    isPush: Bool = false,
    requiredSpeedColor: Color? = nil
  ) {
    self.init(
      distance: fromTo.distance,
      speed: fromTo.speed,
      requiredGroundSpeed: fromTo.requiredGroundSpeed,
      timeOnTarget: timeOnTarget,
      isPush: isPush,
      requiredSpeedColor: requiredSpeedColor
    )
  }
}

#Preview("Speed • Distance • TOT") {
  let helper = PreviewHelper()
  let target = helper.target()
  let math = IPTargetMath(location: helper.preIPLocation, target: target, now: .now)!

  TOTView(fromTo: math.pposToTarget!, timeOnTarget: target.timeOnTarget)
}

#Preview("With required-speed callout") {
  let helper = PreviewHelper()
  let target = helper.target()
  let math = IPTargetMath(location: helper.preIPLocation, target: target, now: .now)!

  TOTView(
    fromTo: math.pposToTarget!,
    timeOnTarget: target.timeOnTarget,
    requiredSpeedColor: .red
  )
}

#Preview("No Ground Speed") {
  let helper = PreviewHelper()
  let target = helper.target()

  TOTView(
    distance: helper.preIPLocation.geoCoordinate.distance(to: target.coordinate),
    timeOnTarget: target.desiredTimeOverIP,
    isPush: true
  )
}
