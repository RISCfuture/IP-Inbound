import CoreLocation
import Foundation

/// Holds the `CLBackgroundActivitySession` that keeps a run's location updates flowing once the app
/// stops being frontmost.
///
/// `FlyView` disables the idle timer, which defends against auto-lock and nothing else: a side-button
/// press, an incoming call, or a glance at a chart app suspends the process, and the CDI, the
/// exit-the-IP countdown and the early/late cue all freeze until the pilot comes back. A session keeps
/// the app in-use for as long as the run lasts, and shows the pilot it is doing so through the system's
/// background-location indicator.
///
/// The session is scoped to the run, not to the location stream — `WarmsLocation` starts that from the
/// setup screens too, where there is nothing to keep alive.
///
/// - Note: A session becomes active only if it is created while the app is foregrounded and in direct
///   use, and only if the app declares `location` in `UIBackgroundModes`. Both platforms do.
@MainActor
final class BackgroundActivityHolder {
  static let shared = BackgroundActivityHolder()

  private var session: CLBackgroundActivitySession?

  private init() {}

  /// Starts a session, or does nothing if one is already running or the process is a preview or a test.
  func begin() {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests, session == nil else { return }
    session = CLBackgroundActivitySession()
  }

  /// Ends the session and lowers the background indicator. Safe to call when none is running.
  func end() {
    session?.invalidate()
    session = nil
  }
}
