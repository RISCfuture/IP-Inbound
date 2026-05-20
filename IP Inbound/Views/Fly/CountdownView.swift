import SwiftUI

struct CountdownView: View {
  var timeOnTarget: Date

  @Environment(\.services)
  private var services

  var body: some View {
    VStack {
      Spacer()

      if timeOnTarget > services.clock.now {
        VStack(alignment: .center, spacing: 0) {
          Text(
            .currentDate,
            format: .timer(
              countingDownIn:
                .now..<timeOnTarget.addingTimeInterval(
                  -Double(services.clock.offsetFromRealTimeSeconds)
                ),
              maxPrecision: .seconds(1)
            )
          )
          .font(.title)
          .contentTransition(.numericText())
          Text("to TOT")
            .font(.caption)
            .textCase(.uppercase)
        }
        .padding(.bottom)
      } else {
        Text("Past TOT")
          .font(.title)
          .padding(.bottom)
      }

      Text("Guidance begins once aircraft is moving.")
        .font(.headline)
        .foregroundStyle(.secondary)

      Spacer()
    }
    .accessibilityIdentifier("countdownView")
  }
}

#Preview {
  CountdownView(timeOnTarget: Date.now.addingTimeInterval(60))
}
