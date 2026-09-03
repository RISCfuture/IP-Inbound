import IP_Inbound_Shared
import SwiftUI

/// The watch's top-level view: run-in guidance for the target the pilot is flying on the iPhone, or a
/// placeholder when no flight is in progress.
struct WatchRootView: View {
  @Environment(WatchConnectivityModel.self)
  private var connectivity

  @Environment(WatchLocationModel.self)
  private var location

  var body: some View {
    Group {
      if let target = connectivity.currentTarget {
        WatchGuidanceView(target: target)
      } else {
        WatchPlaceholderView()
      }
    }
    // The run, not the screen, is what the GPS and the background session belong to. Scoping them to
    // `WatchGuidanceView`'s appearance instead would end both the moment the pilot drops their wrist
    // to fly the aircraft, and would leave the session outstanding — indicator lit, GPS running —
    // when the phone ends the run while the watch app is not frontmost.
    .onChange(of: connectivity.run, initial: true) { _, run in
      switch run {
        case .unknown:
          // The phone has not reported yet, so there is nothing to conclude — and on a launch Core
          // Location made, a session has already been rejoined that this must not tear down.
          break
        case .none:
          location.stop()
          BackgroundActivityHolder.shared.end()
        case .flying:
          location.start()
          BackgroundActivityHolder.shared.begin()
      }
    }
  }
}

#Preview("No Target") {
  WatchRootView()
    .environment(WatchConnectivityModel())
    .environment(WatchLocationModel())
}
