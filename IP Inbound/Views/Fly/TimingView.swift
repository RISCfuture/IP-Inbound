import SwiftUI

struct TimingView: View {
  private static let secondsPerMinute = 60.0

  var timeOnTarget: Date
  var fromTo: FromToMath

  var onTimeDeltaTOT: TimeInterval = 2.0  // seconds ±TOT to be considered "on time"
  /// When `false`, hides the required-ground-speed callout. Used when the aircraft cannot make TOT
  /// even at max speed (bypassing the IP), where a finite “req.” speed would wrongly imply the
  /// time-on-target is still achievable.
  var showRequiredSpeed = true

  private var onTimeRange: ClosedRange<Date> {
    timeOnTarget.addingTimeInterval(
      -onTimeDeltaTOT
    )...timeOnTarget.addingTimeInterval(onTimeDeltaTOT)
  }
  private var cautionRange: ClosedRange<Date> {
    let baseTime = fromTo.distance / fromTo.targetSpeed
    let timeDeviation = baseTime * speedDeviation * Self.secondsPerMinute
    let minTime = timeDeviation.before(date: timeOnTarget)
    let maxTime = timeDeviation.after(date: timeOnTarget)
    return minTime...maxTime
  }

  private var isOnTime: Bool { onTimeRange.contains(fromTo.timeOfArrival) }
  private var isWithinCaution: Bool { cautionRange.contains(fromTo.timeOfArrival) }

  /// Color tier for the arrival readout: green on-time, then the too-slow or too-fast palette in
  /// caution or warning shades by how far the arrival falls outside the on-time window.
  private var textColor: Color {
    if isOnTime { return .init("OnTime") }
    if fromTo.isLate {
      return .init(isWithinCaution ? "TooSlowCaution" : "TooSlowWarning")
    }
    return .init(isWithinCaution ? "TooFastCaution" : "TooFastWarning")
  }

  /// Chevron direction matching the arrival tier: up when late, down when early, doubled at the
  /// warning threshold, checkmark on-time.
  private var icon: String {
    if isOnTime { return "checkmark.circle.fill" }
    if fromTo.isLate {
      return isWithinCaution ? "chevron.up" : "chevron.up.2"
    }
    return isWithinCaution ? "chevron.down" : "chevron.down.2"
  }

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
        Image(systemName: icon)
          .accessibilityHidden(true)
      }
      .font(.title)
      .fontWeight(.black)
      .foregroundStyle(textColor)

      TOTView(
        fromTo: fromTo,
        timeOnTarget: timeOnTarget,
        showSpeed: true,
        requiredSpeedColor: (showRequiredSpeed && !isOnTime) ? textColor : nil
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
