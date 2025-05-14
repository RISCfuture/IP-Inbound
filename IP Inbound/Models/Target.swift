import CoreLocation
import Defaults
import Foundation
import SwiftData

@Model
final class Target: CustomDebugStringConvertible, Identifiable, Equatable, Hashable {
    static let allowableSpeedVariance = 0.1 // % speed change allowable from IP to target speed

    var id = UUID().uuidString
    var name = "New Target"
    var latitude = 0.0
    var longitude = 0.0

    private var _offsetBearing = 0.0 // deg
    var offsetBearing: Double {
        get { _offsetBearing }
        set {
            _offsetBearing = newValue >= 0 ? newValue.truncatingRemainder(dividingBy: 360) : (
                newValue.truncatingRemainder(dividingBy: 360) + 360
            ).truncatingRemainder(dividingBy: 360)
        }
    }

    var offsetBearingIsTrue = false

    var offsetDistance = 4.0 // NM
    var offsetTime = 2.0 // min

    var targetGroundSpeed = 120.0 // kts
    var timeOnTarget: Date?
    var isConfigured = false

    var declination = 0.0 // magnetic declination, deg
    var declinationMeasurement: Measurement<UnitAngle> {
        .init(value: declination, unit: .degrees)
    }

    @Transient var coordinate: Coordinate {
        get {
            .init(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue.latitudeDeg
            longitude = newValue.longitudeDeg
        }
    }

    @Transient var offsetBearingMeasurement: Bearing {
        get {
            .init(angle: offsetBearing,
                  reference: offsetBearingIsTrue ? .true : .magnetic)
        }
        set {
            offsetBearing = newValue.degrees
            offsetBearingIsTrue = newValue.reference == .true
        }
    }
    @Transient var offsetDistanceMeasurement: Measurement<UnitLength> {
        get { .init(value: offsetDistance, unit: .nauticalMiles) }
        set { offsetDistance = newValue.converted(to: .nauticalMiles).value }
    }

    @Transient var offsetTimeMeasurement: Measurement<UnitDuration> {
        get { .init(value: offsetTime, unit: .minutes) }
        set { offsetTime = newValue.converted(to: .minutes).value }
    }

    @Transient var targetGroundSpeedMeasurement: Measurement<UnitSpeed> {
        get { .init(value: targetGroundSpeed, unit: .knots) }
        set { targetGroundSpeed = newValue.converted(to: .knots).value }
    }

    var IPCoordinate: Coordinate {
        coordinate
            .offsetBy(
                bearing: offsetBearingMeasurement
                    .toTrue(declination: declinationMeasurement).angle,
                distance: offsetDistanceMeasurement
            )
    }

    var debugDescription: String {
        return "<Target “\(name)”: \(coordinate); \(offsetBearing)/\(offsetDistance)NM (\(offsetTime)min)>"
    }

    private var targetGroundSpeedMinutes: Double { targetGroundSpeed / 60.0 }

    var desiredTrack: Bearing { offsetBearingMeasurement.reciprocal }
    var desiredTrackMagnetic: Bearing { desiredTrack.toMagnetic(declination: declinationMeasurement) }
    var desiredTrackTrue: Bearing { desiredTrack.toTrue(declination: declinationMeasurement) }

    var desiredTimeOverIP: Date? {
        let runInTime = IPToTarget.length / targetGroundSpeedMeasurement
        return timeOnTarget?.addingTimeInterval(-runInTime.converted(to: .seconds).value)
    }
    var maxAllowableTimeOverIP: Date? {
        let groundSpeed = targetGroundSpeedMeasurement * (1 + Self.allowableSpeedVariance),
            runInTime = IPToTarget.length / groundSpeed
        return timeOnTarget?.addingTimeInterval(-runInTime.converted(to: .seconds).value)
    }

    var IPToTarget: Line {
        .init(from: IPCoordinate, to: coordinate)
    }

    init(name: String,
         coordinate: Coordinate) {
        self.name = name
        self.coordinate = coordinate
        targetGroundSpeed = Defaults[.defaultGroundSpeed]

        let targetGroundSpeedMinutes = Defaults[.defaultGroundSpeed] / 60.0
        switch Defaults[.defaultOffsetType] {
            case .distance:
                offsetDistance = Defaults[.defaultOffset]
                offsetTime = Defaults[.defaultOffset] / targetGroundSpeedMinutes
            case .time:
                offsetTime = Defaults[.defaultOffset]
                offsetDistance = targetGroundSpeedMinutes * Defaults[.defaultOffset]
        }

        calculateDeclination()
    }

    static func == (lhs: Target, rhs: Target) -> Bool {
        lhs.id == rhs.id
    }

    func setOffset(time: Measurement<UnitDuration>) {
        offsetTime = time.converted(to: .minutes).value
        offsetDistance = (targetGroundSpeedMeasurement * time)
            .converted(to: .nauticalMiles)
            .value
    }

    func setOffset(distance: Measurement<UnitLength>) {
        offsetDistance = distance.converted(to: .nauticalMiles).value
        offsetTime = (distance / targetGroundSpeedMeasurement)
            .converted(to: .minutes)
            .value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func calculateDeclination() {
        declination = Geomagnetism(longitude: longitude, latitude: latitude).declination
    }
}
