import CoreLocation
import Foundation

/// How the app starts and stops the location stream a run depends on.
///
/// The view layer owns that stream in the normal course of a run, but a launch Core Location makes
/// on its own never reaches the view layer, so ``BackgroundActivityHolder`` drives it there instead —
/// for exactly as long as the session it rejoined. Each app installs its own at `@main`.
struct RunLocationUpdates {
  /// Puts the location stream back after a relaunch.
  let resume: @MainActor () -> Void

  /// Releases the stream `resume` started, leaving any the view layer holds alone.
  let suspend: @MainActor () -> Void
}

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
/// Core Location relaunches the app in the background when a run outlives the process, and a session
/// the app does not recreate in the first moments of that launch ends for good. ``begin()`` therefore
/// records that a run is outstanding, and ``rejoinRunInProgress(isBackgroundLaunch:)`` picks the
/// record up at `@main` before any view exists.
///
/// - Note: A session becomes active only if it is created while the app is foregrounded and in direct
///   use, and only if the app declares `location` in `UIBackgroundModes`. Both platforms do. From the
///   background the reverse holds: an outstanding session can be rejoined, but a new one cannot be
///   started.
@MainActor
final class BackgroundActivityHolder {
  static let shared = BackgroundActivityHolder()

  /// Internal recovery state rather than a preference, so it stays out of the pilot's `Defaults`
  /// namespace — which the watch target does not link in any case.
  private static let runInProgressKey = "runInProgress"

  /// Installed at `@main`, before any view appears.
  var locationUpdates: RunLocationUpdates?

  private var session: CLBackgroundActivitySession?

  /// Whether the stream the holder is driving is one it started itself, as opposed to the view
  /// layer's own.
  private var isDrivingUpdates = false

  private var isRunInProgress: Bool {
    get { UserDefaults.standard.bool(forKey: Self.runInProgressKey) }
    set { UserDefaults.standard.set(newValue, forKey: Self.runInProgressKey) }
  }

  private init() {}

  /// Starts a session and records that a run is outstanding, or does nothing if one is already
  /// running or the process is a preview or a test.
  func begin() {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests, session == nil else { return }
    session = CLBackgroundActivitySession()
    isRunInProgress = true
  }

  /// Ends the session, lowers the background indicator, and forgets the run. Safe to call when none
  /// is running.
  func end() {
    session?.invalidate()
    session = nil
    isRunInProgress = false
    releaseUpdates()
  }

  /// Rejoins the session a run left outstanding when Core Location relaunched the app, and restarts
  /// the location stream alongside it — the stream is what the system relaunched the app to deliver,
  /// and dropping it forfeits the recovery.
  ///
  /// A launch into the foreground can only ever start a *new* session, which is not what an
  /// outstanding record means, so that record is discarded instead: a run whose process died with the
  /// pilot's phone in their hand is over.
  func rejoinRunInProgress(isBackgroundLaunch: Bool) {
    guard isBackgroundLaunch else {
      isRunInProgress = false
      return
    }
    guard isRunInProgress, session == nil else { return }
    begin()
    driveUpdates()
  }

  private func driveUpdates() {
    guard session != nil, !isDrivingUpdates else { return }
    isDrivingUpdates = true
    locationUpdates?.resume()
  }

  private func releaseUpdates() {
    guard isDrivingUpdates else { return }
    isDrivingUpdates = false
    locationUpdates?.suspend()
  }
}
