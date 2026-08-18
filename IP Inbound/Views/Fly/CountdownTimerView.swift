import SwiftUI

/// A live countdown to `targetDate` with an uppercase caption beneath it. The timer is anchored to
/// the simulated clock by subtracting the services clock offset, so simulated runs count down
/// against the same time base as the rest of the guidance.
struct CountdownTimerView: View {
  var targetDate: Date
  var caption: LocalizedStringKey

  @Environment(\.services)
  private var services

  private var countdownRange: Range<Date> {
    .now..<services.clock.offsetFromRealTime.before(date: targetDate)
  }

  var body: some View {
    VStack(alignment: .center, spacing: 0) {
      Text(
        .currentDate,
        format: .timer(countingDownIn: countdownRange, maxPrecision: .seconds(1))
      )
      .font(.title)
      .contentTransition(.numericText())
      Text(caption)
        .font(.caption)
        .textCase(.uppercase)
    }
  }
}

#Preview("To Push") {
  CountdownTimerView(targetDate: Date.now.addingTimeInterval(90), caption: "to Push")
}

#Preview("To TOT") {
  CountdownTimerView(targetDate: Date.now.addingTimeInterval(60), caption: "to TOT")
}
