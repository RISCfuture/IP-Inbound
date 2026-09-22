import IP_Inbound_Shared
import SwiftUI

struct TimingView: View {
  var timeOnTarget: Date
  var fromTo: FromToMath

  /// Window either side of the TOT within which an arrival reads as “on time”.
  var onTimeDeltaTOT = Measurement(value: 2, unit: UnitDuration.seconds)
  /// When `false`, hides the required-ground-speed callout. Used when the aircraft cannot make TOT
  /// even at max speed (bypassing the IP), where a finite “req.” speed would wrongly imply the
  /// time-on-target is still achievable.
  var showRequiredSpeed = true

  private var tier: TimingTier {
    .init(fromTo: fromTo, timeOnTarget: timeOnTarget, onTimeDeltaTOT: onTimeDeltaTOT)
  }
  private var isOnTime: Bool { tier == .onTime }

  private var arrivalText: String {
    let lateOrEarly = fromTo.isLate ? String(localized: "late") : String(localized: "early")
    return String(
      localized:
        "\(fromTo.timeOfArrival, format: .offset(to: timeOnTarget, maxFieldCount: 1, sign: .never)) \(lateOrEarly)"
    )
  }

  var body: some View {
    VStack {
      Label {
        Text(arrivalText)
          .contentTransition(.numericText())
      } icon: {
        Image(systemName: tier.systemImage)
          .accessibilityHidden(true)
      }
      .font(.title)
      .fontWeight(.black)
      .foregroundStyle(tier.color)

      TOTView(
        fromTo: fromTo,
        timeOnTarget: timeOnTarget,
        requiredSpeedColor: (showRequiredSpeed && !isOnTime) ? tier.color : nil
      )
    }
    .accessibilityIdentifier("timingIndicator")
  }
}

/// A timing tier as the canvas labels it, with the arrival offset that lands a run in it.
private struct TimingTierPreview: CustomStringConvertible {
  var tier: TimingTier

  var description: String {
    switch tier {
      case .onTime: "On Time"
      case .tooFastCaution: "Early — Caution"
      case .tooFastWarning: "Early — Warning"
      case .tooSlowCaution: "Late — Caution"
      case .tooSlowWarning: "Late — Warning"
    }
  }

  /// How far the time on target sits after the projected arrival.
  var timeOnTargetOffset: TimeInterval {
    switch tier {
      case .onTime: 0
      case .tooFastCaution: 20
      case .tooFastWarning: 600
      case .tooSlowCaution: -20
      case .tooSlowWarning: -600
    }
  }
}

#Preview(arguments: TimingTier.allCases.map(TimingTierPreview.init)) { preview in
  let helper = PreviewHelper()
  let math = IPTargetMath(
    location: helper.postIPLocation,
    target: helper.target(minutesFromNow: 1),
    now: .now
  )!
  let fromTo = math.pposToTarget!
  TimingView(
    timeOnTarget: fromTo.timeOfArrival.addingTimeInterval(preview.timeOnTargetOffset),
    fromTo: fromTo
  )
}
