import IP_Inbound_Shared
import WatchKit

/// Exists for the one thing SwiftUI's `App` cannot express: work that must happen the instant the
/// process starts, on a launch Core Location makes on its own, before any view appears.
@MainActor
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
  /// Owned here rather than as the `App`'s state, because a relaunch has to restart the stream before
  /// there is a view to hold it.
  let location = WatchLocationModel()

  func applicationDidFinishLaunching() {
    BackgroundActivityHolder.shared.locationUpdates = .init(
      resume: { [location] in location.start(.session) },
      suspend: { [location] in location.stop(.session) }
    )
    BackgroundActivityHolder.shared.rejoinRunInProgress()
  }
}
