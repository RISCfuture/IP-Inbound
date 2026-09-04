import Foundation
import IP_Inbound_Shared
import MeasurementKit
import RelevanceKit
import WidgetKit

/// One drawing of the complication: the target the watch last heard about, or none.
struct TOTEntry: TimelineEntry {
  let date: Date
  let target: TargetSnapshot?
}

/// Feeds the complication from the App Group container the watch app writes, and tells the Smart
/// Stack when the run-in is worth floating to the front.
struct TOTComplicationProvider: TimelineProvider {
  func placeholder(in _: Context) -> TOTEntry {
    .init(date: .now, target: nil)
  }

  func getSnapshot(in _: Context, completion: @escaping (TOTEntry) -> Void) {
    completion(entry())
  }

  /// Three entries are enough. The countdown ticks itself down, so the only moments the
  /// complication has to be redrawn are the time on target, when it stops counting and says so, and
  /// the run's expiry, when there is no longer a run to count for. Everything else arrives as a
  /// reload from the watch app.
  ///
  /// The expiry entry is what lets the face clear itself. Nothing has to reach the watch for it to
  /// land — no transfer, no wrist raise — which matters, because the phone that would otherwise say
  /// the run is over is exactly the thing that may have stopped saying anything.
  func getTimeline(in _: Context, completion: @escaping (Timeline<TOTEntry>) -> Void) {
    let now = entry()
    var entries = [now]
    if let target = now.target {
      if let timeOnTarget = target.timeOnTarget, timeOnTarget > now.date {
        entries.append(.init(date: timeOnTarget, target: target))
      }
      if let runExpiry = target.runExpiry, runExpiry > now.date {
        entries.append(.init(date: runExpiry, target: nil))
      }
    }
    completion(.init(entries: entries, policy: .never))
  }

  // `relevance()` is async because WidgetKit declares it so, not because it has anything to await.
  // swiftlint:disable async_without_await
  /// Donates the run-in as a scheduled window, so the wrist raise on the way to the IP lands on the
  /// countdown with no tap. The time on target is briefed rather than inferred, so the window is
  /// exact — and outside it the complication stays out of the stack.
  func relevance() async -> WidgetRelevance<Void> {
    guard let window = liveTarget(at: .now)?.runInWindow else { return .init([]) }
    return .init([.init(context: .date(range: window, kind: .scheduled))])
  }
  // swiftlint:enable async_without_await

  private func entry() -> TOTEntry {
    let date = Date.now
    return .init(date: date, target: liveTarget(at: date))
  }

  /// The run the watch last recorded, or `nil` once it has expired.
  ///
  /// The stored snapshot outlives the run it describes: the watch app writes it once and may never
  /// run again, and the phone that would say the run is over may have been force-quit, may be out
  /// of range, or may have spent the transfer budget the system meters. So the face judges what it
  /// holds against the clock rather than trusting it to be current.
  private func liveTarget(at date: Date) -> TargetSnapshot? {
    guard let target = WatchComplicationStore.read(), !target.hasRunExpired(at: date) else {
      return nil
    }
    return target
  }
}
