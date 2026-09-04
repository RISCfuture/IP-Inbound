import Foundation
import WidgetKit

/// The App Group container the watch app writes the flown target into, and the complication reads it
/// back out of.
///
/// A widget extension cannot hold a `WCSession`, so it never hears from the iPhone directly. The
/// container is the whole of the channel: the complication is only ever as fresh as the last time
/// the watch app ran and wrote to it.
public enum WatchComplicationStore {
  /// The widget kind, named once so the app asking for a redraw and the widget declaring itself
  /// cannot drift apart.
  public static let kind = "TOTComplication"

  private static let appGroup = "group.codes.tim.IP-Inbound"
  private static let key = "target"

  private static var defaults: UserDefaults? { .init(suiteName: appGroup) }

  /// Records the target being flown — or that none is — and asks the complication to redraw itself
  /// around it.
  public static func update(_ snapshot: TargetSnapshot?) {
    store(snapshot)
    reloadComplication()
  }

  /// The target the watch app last recorded, or `nil` when no run is in progress.
  public static func read() -> TargetSnapshot? {
    guard let context = defaults?.dictionary(forKey: key) else { return nil }
    return WatchTargetPayload.snapshot(from: context)
  }

  /// Reuses the WatchConnectivity payload's own encoding rather than introducing a second one, so
  /// the target cannot mean one thing on the wire and another in the container.
  private static func store(_ snapshot: TargetSnapshot?) {
    defaults?.set(WatchTargetPayload.context(for: snapshot), forKey: key)
  }

  private static func reloadComplication() {
    WidgetCenter.shared.reloadTimelines(ofKind: kind)
    WidgetCenter.shared.invalidateRelevance(ofKind: kind)
  }
}
