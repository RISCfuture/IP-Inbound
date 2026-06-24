import SwiftUI

struct TimingView: View {
  var timeOnTarget: Date
  var fromTo: FromToMath

  var onTimeDeltaTOT: TimeInterval = 2.0  // seconds ±TOT to be considered "on time"
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
        showSpeed: true,
        requiredSpeedColor: (showRequiredSpeed && !isOnTime) ? tier.color : nil
      )
    }
    .accessibilityIdentifier("timingIndicator")
  }
}

#Preview("On Time") {
  let helper = PreviewHelper()
  let math = IPTargetMath(
    location: helper.postIPLocation,
    target: helper.target(minutesFromNow: 1),
    now: .now
  )
  TimingView(timeOnTarget: math.pposToTarget!.timeOfArrival, fromTo: math.pposToTarget!)
}

#Preview("Early — Caution") {
  let helper = PreviewHelper()
  let math = IPTargetMath(
    location: helper.postIPLocation,
    target: helper.target(minutesFromNow: 1),
    now: .now
  )
  let fromTo = math.pposToTarget!
  TimingView(timeOnTarget: fromTo.timeOfArrival.addingTimeInterval(20), fromTo: fromTo)
}

#Preview("Early — Warning") {
  let helper = PreviewHelper()
  let math = IPTargetMath(
    location: helper.postIPLocation,
    target: helper.target(minutesFromNow: 1),
    now: .now
  )
  let fromTo = math.pposToTarget!
  TimingView(timeOnTarget: fromTo.timeOfArrival.addingTimeInterval(600), fromTo: fromTo)
}

#Preview("Late — Caution") {
  let helper = PreviewHelper()
  let math = IPTargetMath(
    location: helper.postIPLocation,
    target: helper.target(minutesFromNow: 1),
    now: .now
  )
  let fromTo = math.pposToTarget!
  TimingView(timeOnTarget: fromTo.timeOfArrival.addingTimeInterval(-20), fromTo: fromTo)
}

#Preview("Late — Warning") {
  let helper = PreviewHelper()
  let math = IPTargetMath(
    location: helper.postIPLocation,
    target: helper.target(minutesFromNow: 1),
    now: .now
  )
  let fromTo = math.pposToTarget!
  TimingView(timeOnTarget: fromTo.timeOfArrival.addingTimeInterval(-600), fromTo: fromTo)
}
