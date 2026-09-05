import IP_Inbound_Shared
import SwiftUI

/// The watch's top-level view: run-in guidance for the target the pilot is flying on the iPhone, or a
/// placeholder when no flight is in progress.
struct WatchRootView: View {
  @Environment(WatchConnectivityModel.self)
  private var connectivity

  @Environment(WatchLocationModel.self)
  private var location

  @Environment(\.scenePhase)
  private var scenePhase

  var body: some View {
    Group {
      if let target = connectivity.currentTarget {
        // A run's screen belongs to its target. Without this the guidance keeps its identity across
        // a change of target sent from the phone, and with it the phase it carries from fix to fix —
        // so the new run's first fix would be judged against a hold-off the old run was in.
        WatchGuidanceView(target: target)
          .id(target.id)
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
          location.stop(.screen)
          BackgroundActivityHolder.shared.end()
        case .flying:
          location.start(.screen)
          BackgroundActivityHolder.shared.begin()
      }
    }
    // A wrist raised again is how a pilot who has just allowed location access comes back — the
    // watch has no Settings deep link to return from. Gated on a refusal so the stream is only
    // rebuilt where rebuilding it can help.
    .onChange(of: scenePhase) {
      guard scenePhase == .active, location.diagnostics.impediment?.deniesAuthorization == true
      else { return }
      location.retry()
    }
  }
}

#Preview("No Target") {
  WatchRootView()
    .environment(WatchConnectivityModel())
    .environment(WatchLocationModel())
}
