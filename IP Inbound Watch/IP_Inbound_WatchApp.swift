import IP_Inbound_Shared
import SwiftUI

@main
struct IP_Inbound_Watch: App {
  @WKApplicationDelegateAdaptor(WatchAppDelegate.self)
  private var delegate

  @Environment(\.scenePhase)
  private var scenePhase

  @State private var connectivity = WatchConnectivityModel()

  var body: some Scene {
    WindowGroup {
      WatchRootView()
        .environment(connectivity)
        .environment(delegate.location)
        // Frontmost with no run reported means a session `@main` rejoined has no owner. The phone's
        // context arrives moments later, and a run still in progress claims a session of its own —
        // legal from the foreground, where this fires.
        .onChange(of: scenePhase, initial: true) {
          if scenePhase == .active { BackgroundActivityHolder.shared.endUnclaimedRun() }
        }
    }
  }
}
