import SwiftUI

struct SimulatorBanner: View {
    var simName: String?

    private var title: String {
        if let simName { return String(localized: "Using \(simName) simulator data") }
        return String(localized: "Using simulator data")
    }

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange)
            .clipShape(Capsule())
    }
}

#Preview {
    SimulatorBanner()
}
