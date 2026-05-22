import SwiftUI

struct NoLocationView: View {
  private static let stackSpacing: CGFloat = 20

  var body: some View {
    VStack(spacing: Self.stackSpacing) {
      Image(systemName: "location.slash")
        .imageScale(.large)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text("No location.")
        .font(.title)
        .foregroundStyle(.secondary)
    }
    .accessibilityIdentifier("noLocationView")
    .padding()
  }
}

#Preview {
  NoLocationView()
}
