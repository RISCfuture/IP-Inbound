import CoreLocation
import Foundation

struct IPTargetMath: Equatable {
    static let closeToIPTime = Measurement(value: 1, unit: UnitDuration.minutes)

    var coordinate: Coordinate
    var speed: Measurement<UnitSpeed>
    var course: Bearing
    let target: Target

    var pposToIP: FromToMath? {
        guard let timeOnTarget = target.timeOnTarget else { return nil }
        return .init(from: coordinate,
                     to: target.IPCoordinate,
                     speed: speed,
                     track: course,
                     targetSpeed: target.targetGroundSpeedMeasurement,
                     timeOnTarget: timeOnTarget,
                     declination: declination)
    }

    var pposToTarget: FromToMath? {
        guard let timeOnTarget = target.timeOnTarget else { return nil }
        return .init(from: coordinate,
                     to: target.coordinate,
                     speed: speed,
                     track: course,
                     targetSpeed: target.targetGroundSpeedMeasurement,
                     timeOnTarget: timeOnTarget,
                     declination: declination)
    }

    var IPToTarget: FromToMath? {
        guard let timeOnTarget = target.timeOnTarget else { return nil }
        return .init(from: target.IPCoordinate,
                     to: target.IPCoordinate,
                     speed: speed,
                     track: target.desiredTrack,
                     targetSpeed: target.targetGroundSpeedMeasurement,
                     timeOnTarget: timeOnTarget,
                     declination: declination)
    }

    var isPastIP: Bool {
        // Vector from IP to target
        let IPToTargetVector = Coordinate.vector(
            from: target.IPCoordinate,
            to: target.coordinate
        ).normalized

        // Vector from IP to current position
        let IPToPosition = Coordinate.vector(
            from: target.IPCoordinate,
            to: coordinate
        )

        // Project position vector onto direction vector
        let projection = IPToPosition.dot(IPToTargetVector)

        // If the projection is positive, we are past the perpendicular through the IP
        return projection > 0
    }

    var IP_ETA: Date? { pposToIP?.timeOfArrival }

    var IPDeltaTime: TimeInterval? {
        guard let IP_ETA, let desiredTimeOverIP = target.desiredTimeOverIP else { return nil }
        return IP_ETA.timeIntervalSince(desiredTimeOverIP)
    }

    var latestIPDeltaTime: TimeInterval? {
        guard let IP_ETA, let desiredTimeOverIP = target.maxAllowableTimeOverIP else { return nil }
        return IP_ETA.timeIntervalSince(desiredTimeOverIP)
    }

    var crossTrackDistance: Measurement<UnitLength> {
        Coordinate.crosstrackDistance(from: coordinate, to: target.IPToTarget)
    }

    private var declination: Measurement<UnitAngle> { target.declinationMeasurement}

    init(coordinate: Coordinate, speed: Measurement<UnitSpeed>, course: Bearing, target: Target) {
        self.coordinate = coordinate
        self.speed = speed
        self.course = course
        self.target = target
    }

    init(location: CLLocation, target: Target) {
        self.init(coordinate: .init(location.coordinate),
                  speed: .init(value: location.speed, unit: .metersPerSecond),
                  course: .init(angle: location.course, reference: .true),
                  target: target)
    }
}
