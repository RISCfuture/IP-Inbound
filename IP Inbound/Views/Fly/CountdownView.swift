import SwiftUI

struct CountdownView: View {
  var timeOnTarget: Date

  var body: some View {
    Spacer()

    if timeOnTarget > Date.now {
      Text(
        .currentDate, format: .timer(countingDownIn: .now..<timeOnTarget, maxPrecision: .seconds(1))
      )
      .font(.title)
      .padding(.bottom)
      .contentTransition(.numericText())
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
