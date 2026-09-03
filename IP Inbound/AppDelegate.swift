import UIKit

/// Exists for the one thing SwiftUI's `App` cannot express: work that must happen the instant the
/// process starts, on a launch Core Location makes on its own, before any scene connects and any
/// view appears.
///
/// `application(_:didFinishLaunchingWithOptions:)` is where Apple's own streamlined-location sample
/// recreates its session, and it is one of the two delegate methods SwiftUI still calls.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _: UIApplication,
    didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    BackgroundActivityHolder.shared.rejoinRunInProgress()
    return true
  }
}
