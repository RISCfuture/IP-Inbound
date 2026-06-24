import SwiftUI

@main
struct IP_Inbound_Watch: App {
  @State private var connectivity = WatchConnectivityModel()
  @State private var location = WatchLocationModel()

  var body: some Scene {
    WindowGroup {
      WatchRootView()
        .environment(connectivity)
        .environment(location)
    }
  }
}
