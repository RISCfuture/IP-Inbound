import ActivityKit
import Foundation

/// The shared contract for the Time-On-Target Live Activity. The app — which starts and ends the
/// activity — and the widget extension — which renders it — refer to the same `ActivityAttributes`
/// type; ActivityKit matches a running activity to its presentation by this type, so a single shared
/// definition is required. It lives in the app sources (not ``IP Inbound Shared``) because ActivityKit
/// is unavailable on watchOS, and the extension picks it up via explicit target membership.
struct TOTActivityAttributes: ActivityAttributes {
  /// The name of the target being flown, fixed for the life of the activity.
  var targetName: String

  /// The planned IP-to-target leg duration. The progress ring treats this as its full extent: full at
  /// the IP (this far ahead of TOT) and empty at TOT.
  var ipToTargetDuration: Measurement<UnitDuration>

  /// The dynamic state. The planned Time On Target is carried here rather than in the fixed
  /// attributes so that a later edit to the target's TOT can update a running activity.
  struct ContentState: Codable, Hashable {
    /// The instant the activity counts down to.
    var timeOnTarget: Date
  }
}
