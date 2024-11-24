import CoreLocation

private let earthRadius = 6371000.0 // meters

struct Coordinate: Codable, Equatable, Sendable {
    static var zero: Self { .init(latitude: 0, longitude: 0) }

    var latitude: Measurement<UnitAngle>
    var longitude: Measurement<UnitAngle>

    private var radians: Self {
        .init(latitude: latitude.converted(to: .radians),
              longitude: longitude.converted(to: .radians))
    }

    private var degrees: Self {
        .init(latitude: latitude.converted(to: .degrees),
              longitude: longitude.converted(to: .degrees))
    }

    var latitudeDeg: Double { latitude.converted(to: .degrees).value }
    var longitudeDeg: Double { longitude.converted(to: .degrees).value }

    var toCoreLocation: CLLocationCoordinate2D {
        .init(latitude: latitudeDeg, longitude: longitudeDeg)
    }

    init(latitude: Measurement<UnitAngle>, longitude: Measurement<UnitAngle>) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(latitude: Double, longitude: Double, unit: UnitAngle = .degrees) {
        self.init(latitude: .init(value: latitude, unit: unit),
                  longitude: .init(value: longitude, unit: unit))
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude,
                  longitude: coordinate.longitude,
                  unit: .degrees)
    }

    static func vector(from start: Self, to end: Self) -> Vector {
        let startRad = start.radians,
            endRad = end.radians
        let x = cos(endRad.latitude.value) * cos(endRad.longitude.value) - cos(startRad.latitude.value) * cos(startRad.longitude.value),
            y = cos(endRad.latitude.value) * sin(endRad.longitude.value) - cos(startRad.latitude.value) * sin(startRad.longitude.value)

        return .init(x, y)
    }

    static func crosstrackDistance(from position: Self, to line: Line) -> Measurement<UnitLength> {
        let positionRad = position.radians,
            lineRad = line.map(\.radians)

        let delta13 = acos(sin(lineRad.from.latitude.value) * sin(positionRad.latitude.value) + cos(lineRad.from.latitude.value) * cos(positionRad.latitude.value) * cos(positionRad.longitude.value - lineRad.from.longitude.value)),
            theta13 = atan2(sin(positionRad.longitude.value - lineRad.from.longitude.value) * cos(positionRad.latitude.value),
                            cos(lineRad.from.latitude.value) * sin(positionRad.latitude.value) - sin(lineRad.from.latitude.value) * cos(positionRad.latitude.value) * cos(positionRad.longitude.value - lineRad.from.longitude.value)),
            theta12 = atan2(sin(lineRad.to.longitude.value - lineRad.from.longitude.value) * cos(lineRad.to.latitude.value),
                            cos(lineRad.from.latitude.value) * sin(lineRad.to.latitude.value) - sin(lineRad.from.latitude.value) * cos(lineRad.to.latitude.value) * cos(lineRad.to.longitude.value - lineRad.from.longitude.value)),
            deltaXT = asin(sin(delta13) * sin(theta13 - theta12)) * earthRadius

        return .init(value: -deltaXT, unit: .meters)
    }

    func bearing(to coordinate: Self) -> Bearing {
        let startRad = radians,
            endRad = coordinate.radians,
            deltaLon = endRad.longitude.value - startRad.longitude.value,
            y = sin(deltaLon) * cos(endRad.latitude.value),
            x = cos(startRad.latitude.value) * sin(endRad.latitude.value) - sin(startRad.latitude.value) * cos(endRad.latitude.value) * cos(deltaLon),
            initialBearingRad = atan2(y, x),
            initialBearing = initialBearingRad * 180 / .pi
        let bearingDeg = (initialBearing + 360).truncatingRemainder(dividingBy: 360)
        return .init(angle: bearingDeg, reference: .true)
    }

    func distance(to coordinate: Self) -> Measurement<UnitLength> {
        let startRad = radians,
            endRad = coordinate.radians,
            deltaLat = endRad.latitude.value - startRad.latitude.value,
            deltaLon = endRad.longitude.value - startRad.longitude.value,
            a = pow(sin(deltaLat / 2), 2) + cos(startRad.latitude.value) * cos(endRad.latitude.value) * pow(sin(deltaLon / 2), 2),
            c = 2 * atan2(sqrt(a), sqrt(1 - a))
        let distanceM = earthRadius * c
        return .init(value: distanceM, unit: .meters)
    }

    func offsetBy(bearing: Measurement<UnitAngle>, distance: Measurement<UnitLength>) -> Self {
        // Convert bearing and current location to radians
        let bearingRad = bearing.converted(to: .radians).value,
            distanceFraction = distance.converted(to: .meters).value / earthRadius,
            coordRad = radians

        // Calculate the new latitude
        let newLatitudeRad = asin(sin(coordRad.latitude.value) * cos(distanceFraction) +
                                  cos(coordRad.latitude.value) * sin(distanceFraction) * cos(bearingRad)),
            // Calculate the new longitude
            newLongitudeRad = coordRad.longitude.value +
        atan2(sin(bearingRad) * sin(distanceFraction) * cos(coordRad.latitude.value),
              cos(distanceFraction) - sin(coordRad.latitude.value) * sin(newLatitudeRad))

        return .init(latitude: newLatitudeRad, longitude: newLongitudeRad, unit: .radians)
    }
}

struct Line: Codable, Equatable, Sendable {
    var from: Coordinate
    var to: Coordinate

    var length: Measurement<UnitLength> {
        return from.distance(to: to)
    }

    func map(_ transform: (Coordinate) -> Coordinate) -> Self {
        .init(from: transform(from), to: transform(to))
    }
}

struct Vector: Codable, Equatable, Sendable {
    static let zero: Self = .init(0, 0)

    let x: Double
    let y: Double

    var magnitude: Double { sqrt(dot(self)) }

    var normalized: Self { .init(x / magnitude, y / magnitude) }

    init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }

    func dot(_ rhs: Self) -> Double { x * rhs.x + y * rhs.y }
}

struct Bearing: Codable, Equatable, Sendable, CustomDebugStringConvertible {
    var angle: Measurement<UnitAngle>
    var reference: Reference

    var reciprocal: Self {
        let reciprocal = (degrees + 180).truncatingRemainder(dividingBy: 360),
            clamped = reciprocal >= 0 ? reciprocal : reciprocal + 360

        return .init(angle: clamped, reference: reference)
    }

    var degrees: Double { angle.converted(to: .degrees).value }
    var radians: Double { angle.converted(to: .radians).value }

    var normalized: Self {
        var normalized = degrees.truncatingRemainder(dividingBy: 360)

        if reference != .relative {
            while normalized < 0 { normalized += 360 }
        }

        return .init(angle: normalized, reference: reference)
    }

    var absoluteValue: Self {
        precondition(reference == .relative, "cannot take abs of non-relative bearing")
        return .init(angle: abs(angle.value), unit: angle.unit, reference: reference)
    }

    var debugDescription: String {
        switch reference {
            case .magnetic:
                "\(angle.debugDescription)M"
            case .true:
                "\(angle.debugDescription)T"
            case .relative:
                angle.debugDescription
        }
    }

    init(angle: Measurement<UnitAngle>, reference: Reference) {
        self.angle = angle
        self.reference = reference
    }

    init(angle: Double, unit: UnitAngle = .degrees, reference: Reference) {
        self.init(angle: .init(value: angle, unit: unit),
                  reference: reference)
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        let angle = lhs.angle - rhs.angle,
            normalized = (angle + Measurement(value: 180, unit: .degrees)).converted(to: .degrees).value.truncatingRemainder(dividingBy: 360) - 180
        return .init(angle: normalized, reference: .relative)
    }

    func toTrue(declination: Measurement<UnitAngle>) -> Self {
        switch reference {
            case .magnetic:
                    .init(angle: angle + declination, reference: .true)
            case .true:
                self
            case .relative:
                preconditionFailure("Cannot convert relative bearing to true")
        }
    }

    func toMagnetic(declination: Measurement<UnitAngle>) -> Self {
        switch reference {
            case .magnetic:
                self
            case .true:
                    .init(angle: angle - declination, reference: .magnetic)
            case .relative:
                preconditionFailure("Cannot convert relative bearing to magnetic")
        }
    }

    enum Reference: Codable {
        case magnetic, `true`, relative
    }
}
