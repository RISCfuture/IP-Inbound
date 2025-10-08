import SwiftUI

struct CountdownView: View {
  var timeOnTarget: Date

  var body: some View {
    Spacer()

    if timeOnTarget > Date.now {
      VStack(alignment: .center, spacing: 0) {
        Text(
          .currentDate,
          format: .timer(countingDownIn: .now..<timeOnTarget, maxPrecision: .seconds(1))
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
}

#Preview {
  CountdownView(timeOnTarget: Date.now.addingTimeInterval(60))
}
