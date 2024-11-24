import SwiftUI

struct TimingView: View {
    var timeOnTarget: Date
    var fromTo: FromToMath

    var onTimeDeltaTOT: TimeInterval = 2.0 // seconds ±TOT to be considered "on time"

    private var cautionDeltaTOT: TimeInterval { onTimeDeltaTOT * 5 }
    private var onTimeRange: ClosedRange<Date> {
        timeOnTarget.addingTimeInterval(-onTimeDeltaTOT)...timeOnTarget.addingTimeInterval(onTimeDeltaTOT)
    }
    private var cautionRange: ClosedRange<Date> {
        let baseTime = fromTo.distance / fromTo.targetSpeed,
            timeDeviation = baseTime * speedDeviation * 60,
            minTime = timeDeviation.before(date: timeOnTarget),
            maxTime = timeDeviation.after(date: timeOnTarget)
        return minTime...maxTime
    }

    var body: some View {
        VStack {
            let textColor: Color = if onTimeRange.contains(fromTo.timeOfArrival) {
                .init("OnTime")
            } else if fromTo.deltaTOT > 0 {
                if cautionRange.contains(fromTo.timeOfArrival) {
                    .init("TooSlowCaution")
                } else {
                    .init("TooSlowWarning")
                }
            } else if cautionRange.contains(fromTo.timeOfArrival) {
                .init("TooFastCaution")
            } else {
                .init("TooFastWarning")
            }

            let icon = if onTimeRange.contains(fromTo.timeOfArrival) {
                "checkmark.circle.fill"
            } else if fromTo.deltaTOT > 0 {
                if cautionRange.contains(fromTo.timeOfArrival) {
                    "chevron.up"
                } else {
                    "chevron.up.2"
                }
            } else if cautionRange.contains(fromTo.timeOfArrival) {
                "chevron.down"
            } else {
                "chevron.down.2"
            }
            let lateOrEarly = fromTo.isLate ? String(localized: "late") : String(localized: "early"),
                TOAFormatted = String(localized: "\(fromTo.timeOfArrival, format: .offset(to: timeOnTarget, maxFieldCount: 1, sign: .never)) \(lateOrEarly)")

            HStack {
                Image(systemName: icon)
                    .accessibilityHidden(true)
                Text(TOAFormatted)
                    .contentTransition(.numericText())
            }
            .font(.title)
            .fontWeight(.black)
            .foregroundStyle(textColor)

            TOTView(fromTo: fromTo, timeOnTarget: timeOnTarget, showSpeed: true)
        }
    }
}

#Preview {
    let helper = PreviewHelper(),
        math = IPTargetMath(location: helper.postIPLocation, target: helper.target(minutesFromNow: 2))
    TimingView(timeOnTarget: Date.now.addingTimeInterval(60), fromTo: math.pposToTarget!)
}
