import SwiftUI

struct CountdownView: View {
  var timeOnTarget: Date

  @Environment(\.services)
  private var services

  var body: some View {
    VStack {
      Spacer()

      if timeOnTarget > services.clock.now {
        CountdownTimerView(targetDate: timeOnTarget, caption: "to TOT")
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
