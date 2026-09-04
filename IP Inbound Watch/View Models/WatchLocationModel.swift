import CoreLocation
import IP_Inbound_Shared
import Observation

/// Streams the watch's own GPS fixes (position, course, and ground speed) for run-in guidance, and
/// tracks whether location access has been denied. Mirrors the iPhone's airborne location
/// configuration so the guidance math behaves identically.
///
/// Two owners hold the stream: the view layer, for as long as a run is on screen, and the
/// background-activity holder that rejoins a session at launch, for as long as that session outlives
/// a run. Holds are counted rather than exclusive, so neither owner's release can take the GPS away
/// from the other — a run still being flown keeps its fixes when the holder disposes of a session no
/// screen claimed.
@MainActor
@Observable
final class WatchLocationModel {
  private(set) var location: CLLocation?

  /// Why Core Location is withholding a fix, or `.clean` while nothing is wrong.
  private(set) var diagnostics = LocationDiagnostics.clean

  private var listenerCount = 0

  /// Which run of the stream ``task`` belongs to. A stream that ends after ``retry()`` has already
  /// replaced it would otherwise clear the handle of the one now running, stranding a task nothing
  /// can cancel.
  private var generation = 0

  private var task: Task<Void, Never>?

  init() {}

  /// Stands a fix in for the live stream, so a preview can draw the guidance a fix produces rather
  /// than the acquiring-GPS placeholder every previewed model would otherwise be stuck on.
  init(previewLocation: CLLocation) {
    location = previewLocation
  }

  /// Takes a listener's hold on the stream, starting it for the first one and prompting for
  /// when-in-use access on first use.
  func start() {
    listenerCount += 1
    if listenerCount == 1 { startStream() }
  }

  /// Releases one listener's hold, stopping the stream when the last one lets go.
  ///
  /// A release with no hold outstanding is ignored rather than counted: the holder suspends a stream
  /// it may never have resumed, and the run's own screen can report the run over first. Counted,
  /// that would leave the tally below zero, where ``start()`` could never see it reach one again and
  /// the watch would show no fix for the rest of the process.
  func stop() {
    guard listenerCount > 0 else { return }
    listenerCount -= 1
    if listenerCount == 0 { stopStream() }
  }

  /// Puts the stream back for the listeners still holding it, without disturbing their holds.
  ///
  /// Core Location ends the stream on a refusal and does not re-offer it, so a pilot who allows
  /// access afterwards would stay on the refusal screen for the rest of the run. Nothing else
  /// restarts it: the watch has no Settings deep link to come back from, only a wrist raised again.
  func retry() {
    guard listenerCount > 0 else { return }
    startStream()
  }

  /// Under UI tests a seeded fix stands in for the live stream so no permission prompt appears.
  private func startStream() {
    if let seededLocation = WatchUITestSupport.seededLocation {
      location = seededLocation
      return
    }
    task?.cancel()
    generation += 1
    let startedGeneration = generation
    task = Task { [weak self] in
      await self?.consumeLiveUpdates()
      self?.streamEnded(generation: startedGeneration)
    }
  }

  /// Reads each update's diagnostics before its fix, and unconditionally. An update carrying a
  /// refusal carries no location, so taking the location first would swallow exactly the updates
  /// that say why guidance stopped, leaving the last fix frozen on the screen instead.
  private func consumeLiveUpdates() async {
    do {
      for try await update in CLLocationUpdate.liveUpdates(.airborne) {
        // Breaks rather than filtering on `Task.isCancelled`: a `where` clause would discard the
        // update and go back for another, and this stream does not end on its own.
        if Task.isCancelled { break }
        diagnostics = .init(update)
        if let location = update.location { self.location = location }
      }
    } catch {
      // The stream failed; keep the last known fix on screen until ``retry()`` puts it back.
    }
  }

  private func streamEnded(generation: Int) {
    guard generation == self.generation else { return }
    task = nil
  }

  private func stopStream() {
    task?.cancel()
    task = nil
  }
}
