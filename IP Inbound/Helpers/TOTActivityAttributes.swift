import ActivityKit
import Foundation

/// The shared contract for the Time-On-Target Live Activity. The app — which starts and ends the
/// activity — and the widget extension — which renders it — refer to the same `ActivityAttributes`
/// type; ActivityKit matches a running activity to its presentation by this type, so a single shared
/// definition is required. It lives in the app sources (not `IP Inbound Shared`) because ActivityKit
/// is unavailable on watchOS, and the extension picks it up via explicit target membership.
/// `Equatable` so the app can ask whether a running activity is the one it wants: the attributes are
/// fixed when an activity is requested, so they are what says which target it was drawn for.
struct TOTActivityAttributes: ActivityAttributes, Equatable {
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

    /// How the projected IP crossing compares with the one the run-in was planned around: negative
    /// early, positive late. `nil` once the IP is behind the aircraft, or before there is a fix to
    /// solve from.
    var ipDeltaTime: Measurement<UnitDuration>?

    /// The distance still to fly to the IP, where the run-in begins. `nil` in the same cases as
    /// ``ipDeltaTime``.
    var distanceToIP: Measurement<UnitLength>?

    init(
      timeOnTarget: Date,
      ipDeltaTime: Measurement<UnitDuration>? = nil,
      distanceToIP: Measurement<UnitLength>? = nil
    ) {
      self.timeOnTarget = timeOnTarget
      self.ipDeltaTime = ipDeltaTime
      self.distanceToIP = distanceToIP
    }
  }
}
