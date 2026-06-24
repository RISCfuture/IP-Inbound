import SwiftUI

/// Shown when no target is being flown on the iPhone, directing the pilot to start one there.
struct WatchPlaceholderView: View {
  var body: some View {
    ContentUnavailableView {
      Label("No Target", systemImage: "scope")
    } description: {
      Text("Start flying a target on your iPhone to see run-in guidance here.")
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("watchPlaceholder")
  }
}

#Preview {
  WatchPlaceholderView()
}
