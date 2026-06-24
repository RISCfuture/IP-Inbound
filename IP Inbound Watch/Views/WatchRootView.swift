import SwiftUI

/// The watch's top-level view: run-in guidance for the target the pilot is flying on the iPhone, or a
/// placeholder when no flight is in progress.
struct WatchRootView: View {
  @Environment(WatchConnectivityModel.self)
  private var connectivity

  var body: some View {
    if let target = connectivity.currentTarget {
      WatchGuidanceView(target: target)
    } else {
      WatchPlaceholderView()
    }
  }
}

#Preview("No Target") {
  WatchRootView()
    .environment(WatchConnectivityModel())
    .environment(WatchLocationModel())
}
