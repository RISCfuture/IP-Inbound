import CoreLocation
import Observation

/// Streams the watch's own GPS fixes (position, course, and ground speed) for run-in guidance, and
/// tracks whether location access has been denied. Mirrors the iPhone's airborne location
/// configuration so the guidance math behaves identically.
@MainActor
@Observable
final class WatchLocationModel {
  private(set) var location: CLLocation?

  /// Why Core Location is withholding a fix, or `.clean` while nothing is wrong.
  private(set) var diagnostics = LocationDiagnostics.clean

  private var task: Task<Void, Never>?

  /// Begins streaming live updates, prompting for when-in-use access on first use. Under UI tests a
  /// seeded fix stands in for the live stream so no permission prompt appears.
  func start() {
    guard task == nil else { return }
    if let seededLocation = WatchUITestSupport.seededLocation {
      location = seededLocation
      return
    }
    task = Task { [weak self] in
      do {
        for try await update in CLLocationUpdate.liveUpdates(.airborne) {
          guard let self else { return }
          diagnostics = .init(update)
          if let location = update.location { self.location = location }
        }
      } catch {
        // The stream ended or failed; keep the last known fix on screen.
      }
    }
  }

  func stop() {
    task?.cancel()
    task = nil
  }
}
