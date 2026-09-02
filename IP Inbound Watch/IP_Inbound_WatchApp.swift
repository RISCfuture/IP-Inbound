import SwiftUI

@main
struct IP_Inbound_Watch: App {
  @WKApplicationDelegateAdaptor(WatchAppDelegate.self)
  private var delegate

  @State private var connectivity = WatchConnectivityModel()

  var body: some Scene {
    WindowGroup {
      WatchRootView()
        .environment(connectivity)
        .environment(delegate.location)
    }
  }
}
