import Foundation

struct FromToMath: Equatable {
    private static let bankAngle = Measurement(value: 45, unit: UnitAngle.degrees)
        .converted(to: .radians).value
    private static let smallTurn = Measurement(value: 10, unit: UnitAngle.degrees)
        .converted(to: .radians).value
    private static let g = Measurement(value: 1, unit: UnitAcceleration.gravity)
        .converted(to: .metersPerSecondSquared).value

    var from: Coordinate
    let to: Coordinate

    var speed: Measurement<UnitSpeed>

    var track: Bearing
    var trackTrue: Bearing {
        track.toTrue(declination: declination)
    }
    var trackMagnetic: Bearing {
        track.toMagnetic(declination: declination)
    }

    let targetSpeed: Measurement<UnitSpeed>
    let timeOnTarget: Date

    var bearing: Bearing { from.bearing(to: to) } // deg
    var bearingTrue: Bearing {
        bearing.toTrue(declination: declination)
    }
    var bearingMagnetic: Bearing {
        bearing.toMagnetic(declination: declination)
    }

    var distance: Measurement<UnitLength> { from.distance(to: to) }
    var timeToGo: Measurement<UnitDuration> {
        let straightLineTime = distance / speed,
            deltaAngle = min(
                (bearingMagnetic - trackMagnetic).normalized.absoluteValue.radians,
                (bearingMagnetic - trackMagnetic).normalized.absoluteValue.radians
            )

        guard deltaAngle > Self.smallTurn else { return straightLineTime }

        let turnRate = Self.g * tan(Self.bankAngle) / speed.converted(to: .metersPerSecond).value,
            turnTimeS = deltaAngle / turnRate,
            turnTime = Measurement(value: turnTimeS, unit: UnitDuration.seconds)

        return straightLineTime + turnTime
    }
    var timeOfArrival: Date { timeToGo.afterNow }
    var deltaTOT: TimeInterval {
        timeOfArrival.timeIntervalSince(timeOnTarget)
    }

    var deltaTOTMeasurement: Measurement<UnitDuration> {
        .init(value: deltaTOT, unit: .seconds)
    }

    var isLate: Bool { deltaTOT > 0 }
    var isEarly: Bool { deltaTOT < 0 }

    private let declination: Measurement<UnitAngle>

    init(from: Coordinate,
         to: Coordinate,
         speed: Measurement<UnitSpeed>,
         track: Bearing,
         targetSpeed: Measurement<UnitSpeed>,
         timeOnTarget: Date,
         declination: Measurement<UnitAngle>) {
        self.from = from
        self.to = to
        self.speed = speed
        self.track = track
        self.targetSpeed = targetSpeed
        self.timeOnTarget = timeOnTarget
        self.declination = declination
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.from == rhs.from &&
        lhs.to == rhs.to &&
        lhs.speed == rhs.speed &&
        lhs.targetSpeed == rhs.targetSpeed &&
        lhs.timeOnTarget == rhs.timeOnTarget
    }
}
