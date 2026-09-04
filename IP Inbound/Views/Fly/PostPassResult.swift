import Foundation
import MeasurementKit
import Observation

@Observable
final class PostPassResult {
  private(set) var capture: Capture?
  private(set) var crossingTime: Date?

  /// Records when the aircraft actually crossed the target. Only the first crossing is kept, so an
  /// early overfly is timed at the crossing rather than later when the post-pass state is entered.
  func recordCrossing(at time: Date) {
    guard crossingTime == nil else { return }
    crossingTime = time
  }

  func capture(targetName: String, timeOnTarget: Date) {
    guard capture == nil else { return }
    capture = .init(
      targetName: targetName,
      miss: crossingTime?.elapsed(since: timeOnTarget)
    )
  }

  func reset() {
    capture = nil
    crossingTime = nil
  }

  struct Capture: Equatable {
    let targetName: String

    /// How far the crossing fell from the planned time-on-target: positive late, negative early.
    ///
    /// `nil` when the run lapsed with the target still ahead of it. Nothing was crossed, so there
    /// is nothing to time — and the only moment available, the one the guidance stood down at, is
    /// the grace period rather than anything the aircraft flew.
    let miss: Measurement<UnitDuration>?

    /// Whether the aircraft actually crossed the target, as opposed to the run lapsing with the
    /// target still ahead of it. The two are different results and read differently: one is a pass
    /// flown, the other a pass that never happened.
    var crossedTarget: Bool { miss != nil }
  }
}

enum NextTarget {
  static func next(after current: Target, in targets: [Target], now: Date) -> Target? {
    // The next target is the soonest one whose TOT is after the current target’s — regardless of
    // whether that time has already passed — so a behind-schedule run still offers the next leg.
    let threshold = current.timeOnTarget ?? now

    return
      targets
      .filter { $0.id != current.id }
      .compactMap { target -> (Target, Date)? in
        guard let timeOnTarget = target.timeOnTarget, timeOnTarget > threshold else {
          return nil
        }
        return (target, timeOnTarget)
      }
      .min { $0.1 < $1.1 }?
      .0
  }
}
