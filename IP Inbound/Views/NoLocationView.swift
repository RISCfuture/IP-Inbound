import SwiftUI

struct NoLocationView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash")
                .imageScale(.large)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            Text("No location.")
                .font(.title)
                .foregroundStyle(.secondary)
        }.padding()
    }
}

#Preview {
    NoLocationView()
}
