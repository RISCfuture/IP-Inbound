import Foundation

extension IPTargetMath {
  var isPastTarget: Bool {
    // Vector from IP to target (the run-in axis)
    let IPToTargetVector = Coordinate.vector(
      from: target.IPCoordinate,
      to: target.coordinate
    ).normalized

    // Vector from target to current position
    let targetToPosition = Coordinate.vector(
      from: target.coordinate,
      to: coordinate
    )

    // Project position vector onto the run-in axis
    let projection = targetToPosition.dot(IPToTargetVector)

    // If the projection is positive, we are beyond the target along the run-in axis
    return projection > 0
  }
}
