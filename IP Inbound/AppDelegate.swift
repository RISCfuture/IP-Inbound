import UIKit

/// Exists for the one thing SwiftUI's `App` cannot express: work that must happen on a launch Core
/// Location makes on its own, before any scene connects and any view appears.
///
/// `application(_:didFinishLaunchingWithOptions:)` is where Apple's own streamlined-location sample
/// recreates its session, and it hands the `UIApplication` in — a launch reporting
/// `UIApplication.State.background` is one the system made, not the pilot.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    BackgroundActivityHolder.shared.locationUpdates = .locationStreamer
    BackgroundActivityHolder.shared.rejoinRunInProgress(
      isBackgroundLaunch: application.applicationState == .background
    )
    return true
  }
}
