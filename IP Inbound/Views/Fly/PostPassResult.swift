import Foundation
import Observation

@Observable
final class PostPassResult {
  private(set) var capture: Capture?

  var isCaptured: Bool { capture != nil }

  func capture(targetName: String, missSeconds: TimeInterval) {
    guard capture == nil else { return }
    capture = .init(targetName: targetName, missSeconds: missSeconds)
  }

  func reset() {
    capture = nil
  }

  struct Capture: Equatable {
    let targetName: String
    let missSeconds: TimeInterval
  }
}

enum NextTarget {
  static func next(after current: Target, in targets: [Target], now: Date) -> Target? {
    let threshold = Swift.max(current.timeOnTarget ?? now, now)

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
