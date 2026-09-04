import CoreLocation
import Foundation

/// How the app starts and stops the location stream a run depends on.
///
/// The view layer owns that stream in the normal course of a run, but a launch Core Location makes
/// on its own never reaches the view layer, so ``BackgroundActivityHolder`` drives it there instead —
/// for exactly as long as the session it rejoined. Each app installs its own at `@main`.
public struct RunLocationUpdates {
  /// Puts the location stream back after a relaunch.
  public let resume: @MainActor () -> Void

  /// Releases the stream `resume` started, leaving any the view layer holds alone.
  public let suspend: @MainActor () -> Void

  /// - Parameters:
  ///   - resume: puts the location stream back after a relaunch.
  ///   - suspend: releases the stream `resume` started.
  public init(resume: @escaping @MainActor () -> Void, suspend: @escaping @MainActor () -> Void) {
    self.resume = resume
    self.suspend = suspend
  }
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
/// the app does not recreate in the first moments of that launch ends for good.
/// ``begin(targetID:)`` therefore records that a run is outstanding, along with the target it is
/// flying, and ``rejoinRunInProgress()`` picks the record up at `@main` before any view exists.
///
/// A rejoined session arrives unclaimed: no run is on screen, and on a launch the system made none
/// ever will be. ``endUnclaimedRun()`` disposes of one the moment the app becomes frontmost with no
/// Fly screen showing, which is also what clears a record left behind by a force-quit or a crash.
/// Adjudicating there rather than at launch is deliberate — under the scene lifecycle an app launched
/// into the foreground still reports `UIApplication.State.background` while it finishes launching, so
/// the launch itself cannot say which kind it is.
///
/// - Note: A session becomes active only if it is created while the app is foregrounded and in direct
///   use, and only if the app declares `location` in `UIBackgroundModes`. Both platforms do. From the
///   background the reverse holds: an outstanding session can be rejoined, but a new one cannot be
///   started.
@MainActor
public final class BackgroundActivityHolder {
  /// The process's holder. A run outlives any one screen, so the session it depends on is
  /// process-wide too.
  public static let shared = BackgroundActivityHolder()

  /// Internal recovery state rather than a preference, so it stays out of the pilot's `Defaults`
  /// namespace — which the watch target does not link in any case.
  private static let runInProgressKey = "runInProgress"

  /// Which target the outstanding run is flying, so a relaunched process can put the pilot back on
  /// it. A plain identifier rather than the model object: this file compiles into the watch too,
  /// where there is no `Target`.
  private static let runTargetIDKey = "runTargetID"

  /// Installed at `@main`, before any view appears, by a platform whose location stream has no other
  /// owner outside the view layer. The watch installs one; iPhone does not, because its run
  /// controller holds the stream for as long as the run it is flying.
  public var locationUpdates: RunLocationUpdates?

  private var session: CLBackgroundActivitySession?

  /// Whether a run on screen owns the current session, as opposed to one ``rejoinRunInProgress()``
  /// recreated for a run this process did not start.
  private var isClaimed = false

  /// Whether the stream the holder is driving is one it started itself, as opposed to the view
  /// layer's own.
  private var isDrivingUpdates = false

  /// The target the outstanding run is flying, or `nil` when no run is recorded — or when the run
  /// was recorded by the watch, which flies a target it never named.
  ///
  /// Answered only while a run is actually outstanding, so the two halves of the record cannot
  /// disagree: a stale identifier read after the run ended would reopen the Fly screen on a run the
  /// pilot has already left.
  public private(set) var runTargetID: String? {
    get { isRunInProgress ? UserDefaults.standard.string(forKey: Self.runTargetIDKey) : nil }
    set {
      // Assigning `nil` through `UserDefaults.set(_:forKey:)` does not clear the key: the optional
      // is boxed into the `Any?` parameter as a *non-nil* value that happens to wrap nothing, and
      // the stored identifier survives untouched.
      guard let newValue else {
        UserDefaults.standard.removeObject(forKey: Self.runTargetIDKey)
        return
      }
      UserDefaults.standard.set(newValue, forKey: Self.runTargetIDKey)
    }
  }

  /// Whether a run is recorded as outstanding: one this process is flying, or one a departed
  /// process left behind. Callers tearing a run down consult it so that a second teardown — a
  /// screen leaving after the run already expired — costs nothing.
  public var isRunOutstanding: Bool { isRunInProgress }

  /// Whether a run on screen owns the current session, as opposed to one ``rejoinRunInProgress()``
  /// recreated for a run this process did not start.
  public var isRunClaimed: Bool { isClaimed }

  private var isRunInProgress: Bool {
    get { UserDefaults.standard.bool(forKey: Self.runInProgressKey) }
    set { UserDefaults.standard.set(newValue, forKey: Self.runInProgressKey) }
  }

  private init() {}

  /// Claims a session for the run the pilot is flying now, starting one if none is outstanding, and
  /// records that a run is in progress. Does nothing under previews and tests.
  ///
  /// - Parameter targetID: which target is being flown, so a relaunch can reopen it. The watch omits
  ///   it: its target arrives over WatchConnectivity, which outlives the process on its own.
  public func begin(targetID: String? = nil) {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests else { return }
    isClaimed = true
    isRunInProgress = true
    runTargetID = targetID
    startSession()
  }

  /// Ends the session, lowers the background indicator, and forgets the run. Safe to call when none
  /// is running.
  public func end() {
    isClaimed = false
    isRunInProgress = false
    runTargetID = nil
    session?.invalidate()
    session = nil
    releaseUpdates()
  }

  /// Whether a screen flying `targetID` is still the one the outstanding run belongs to, and so the
  /// one that should tear it down.
  ///
  /// SwiftUI does not promise that a departing screen's `onDisappear` runs before its replacement's
  /// `onAppear`, and flying straight on to the next target replaces the whole subtree. Torn down
  /// unconditionally, the screen the pilot just left would end the run the screen they just arrived
  /// at has already begun. A record naming no target — the watch's, or one written before this app
  /// recorded them — is nobody else's to lose, so it is the caller's to end.
  public func ownsRun(flying targetID: String) -> Bool {
    runTargetID == nil || runTargetID == targetID
  }

  /// Rejoins the session a run left outstanding when Core Location relaunched the app, and restarts
  /// the location stream alongside it — the stream is what the system relaunched the app to deliver,
  /// and dropping it forfeits the recovery. Belongs at `@main`: the window is the first moments of
  /// the launch, and a session recreated later is a new one rather than the run's.
  public func rejoinRunInProgress() {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests, isRunInProgress else { return }
    startSession()
    driveUpdates()
  }

  /// Ends a session no run on screen has claimed. With the app frontmost and no Fly screen showing,
  /// a rejoined session belongs to a run that ended while the app was not running — as does the
  /// record a force-quit or a crash left behind.
  ///
  /// A launch with no run recorded at all has nothing to adjudicate, and says so by doing nothing:
  /// every foregrounding reaches here, and the callers layered over this one answer for a run by
  /// spending budget the system meters.
  public func endUnclaimedRun() {
    guard !isClaimed, isRunInProgress else { return }
    end()
  }

  private func startSession() {
    guard session == nil else { return }
    session = CLBackgroundActivitySession()
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
