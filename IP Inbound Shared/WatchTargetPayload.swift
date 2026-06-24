import Foundation

/// Encodes and decodes the currently-flown ``TargetSnapshot`` for transmission between the iPhone and
/// Apple Watch as a WatchConnectivity application context. An empty payload means no target is being
/// flown, returning the watch to its placeholder.
enum WatchTargetPayload {
  private static let key = "target"

  /// Builds the application-context dictionary for a snapshot, or an empty payload when `nil`.
  static func context(for snapshot: TargetSnapshot?) -> [String: Any] {
    let data = snapshot.flatMap { try? JSONEncoder().encode($0) } ?? Data()
    return [key: data]
  }

  /// Decodes the snapshot from a received application context, or `nil` when none is present.
  static func snapshot(from context: [String: Any]) -> TargetSnapshot? {
    guard let data = context[key] as? Data, !data.isEmpty else { return nil }
    return try? JSONDecoder().decode(TargetSnapshot.self, from: data)
  }
}
