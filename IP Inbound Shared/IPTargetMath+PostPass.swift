import Foundation
import MeasurementKitLocation

extension IPTargetMath {
  /// Whether the target is behind the aircraft, measured along the run-in axis rather than by
  /// distance, so a wide pass still counts as flown.
  public var isPastTarget: Bool {
    // Vector from IP to target (the run-in axis)
    let IPToTargetVector = Coordinate.vector(
      from: target.IPCoordinate,
      to: target.coordinate
    )

    // A zero-length axis (the IP coincides with the target) has no run-in direction to project
    // onto; normalizing it would yield NaN, so report not-past rather than a spurious result.
    guard IPToTargetVector.magnitude > 0 else { return false }

    // Vector from target to current position
    let targetToPosition = Coordinate.vector(
      from: target.coordinate,
      to: coordinate
    )

    // If the projection onto the run-in axis is positive, we are beyond the target.
    let projection = targetToPosition.dot(IPToTargetVector.normalized)
    return projection > 0
  }

  /// True once the planned Time-On-Target has elapsed against the injected
  /// clock. False when `timeOnTarget` is unset. Pairs with ``isPastTarget``
  /// to gate the post-pass state: holding past the target before TOT keeps the
  /// IP→Target guidance visible.
  public var isAfterTOT: Bool {
    guard let timeOnTarget = target.timeOnTarget else { return false }
    return now >= timeOnTarget
  }
}
