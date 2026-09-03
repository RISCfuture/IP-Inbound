import Foundation
import IP_Inbound_Shared

extension Target: GuidanceTarget {
  /// A `Codable` value-type copy of this target's guidance geometry, for transmission to the Apple
  /// Watch over WatchConnectivity.
  var snapshot: TargetSnapshot {
    .init(
      id: id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      offsetBearing: offsetBearing,
      offsetBearingIsTrue: offsetBearingIsTrue,
      offsetDistance: offsetDistance,
      targetGroundSpeed: targetGroundSpeed,
      timeOnTarget: timeOnTarget,
      declination: declination
    )
  }
}
