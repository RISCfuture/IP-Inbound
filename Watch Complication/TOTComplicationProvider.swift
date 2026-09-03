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

  /// Two entries are enough. The countdown ticks itself down, so the only moment the complication
  /// has to be redrawn is the time on target itself, when it stops counting and says so. Everything
  /// else arrives as a reload from the watch app.
  func getTimeline(in _: Context, completion: @escaping (Timeline<TOTEntry>) -> Void) {
    let now = entry()
    var entries = [now]
    if let timeOnTarget = now.target?.timeOnTarget, timeOnTarget > now.date {
      entries.append(.init(date: timeOnTarget, target: now.target))
    }
    completion(.init(entries: entries, policy: .never))
  }

  // `relevance()` is async because WidgetKit declares it so, not because it has anything to await.
  // swiftlint:disable async_without_await
  /// Donates the run-in as a scheduled window, so the wrist raise on the way to the IP lands on the
  /// countdown with no tap. The time on target is briefed rather than inferred, so the window is
  /// exact — and outside it the complication stays out of the stack.
  func relevance() async -> WidgetRelevance<Void> {
    guard let window = WatchComplicationStore.read()?.runInWindow else { return .init([]) }
    return .init([.init(context: .date(range: window, kind: .scheduled))])
  }
  // swiftlint:enable async_without_await

  private func entry() -> TOTEntry {
    .init(date: .now, target: WatchComplicationStore.read())
  }
}
