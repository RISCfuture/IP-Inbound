import SwiftUI

struct SimulatorBanner: View {
  private static let
    horizontalPadding = 16.0,
    verticalPadding = 8.0

  var simName: String?

  private var title: String {
    if let simName { return String(localized: "Using \(simName) simulator data") }
    return String(localized: "Using simulator data")
  }

  var body: some View {
    Text(title)
      .font(.headline)
      .foregroundStyle(.white)
      .padding(.horizontal, Self.horizontalPadding)
      .padding(.vertical, Self.verticalPadding)
      .background(Color.orange)
      .clipShape(Capsule())
      .accessibilityIdentifier("simulatorBanner")
  }
}

#Preview("Generic") {
  SimulatorBanner()
}

#Preview("Named simulator") {
  SimulatorBanner(simName: "X-Plane")
}
