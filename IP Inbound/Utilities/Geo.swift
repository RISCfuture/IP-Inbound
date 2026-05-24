import CoreLocation

private let earthRadius = 6371000.0  // meters

public struct Coordinate: Codable, Equatable, Sendable, Hashable {
  static var zero: Self { .init(latitude: 0, longitude: 0) }

  var latitude: Measurement<UnitAngle>
  var longitude: Measurement<UnitAngle>

  private var radians: Self {
    .init(
      latitude: latitude.converted(to: .radians),
      longitude: longitude.converted(to: .radians)
    )
  }

  var latitudeDeg: Double { latitude.converted(to: .degrees).value }
  var longitudeDeg: Double { longitude.converted(to: .degrees).value }

  var toCoreLocation: CLLocationCoordinate2D {
    .init(latitude: latitudeDeg, longitude: longitudeDeg)
  }

  var utmBand: Character {
    let bands: [Character] = [
      "C", "D", "E", "F", "G", "H", "J", "K", "L", "M",
      "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X"
    ]
    let lat = latitudeDeg
    if lat < -80.0 { return "A" }
    if lat >= 84.0 { return "Z" }
    let index = Int((lat + 80.0) / 8.0)
    return bands[min(max(index, 0), bands.count - 1)]
  }

  init(latitude: Measurement<UnitAngle>, longitude: Measurement<UnitAngle>) {
    self.latitude = latitude
    self.longitude = longitude
  }

  init(latitude: Double, longitude: Double, unit: UnitAngle = .degrees) {
    self.init(
      latitude: .init(value: latitude, unit: unit),
      longitude: .init(value: longitude, unit: unit)
    )
  }

  init(_ coordinate: CLLocationCoordinate2D) {
    self.init(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      unit: .degrees
    )
  }

  static func vector(from start: Self, to end: Self) -> Vector {
    let startRad = start.radians
    let endRad = end.radians
    let x =
      cos(endRad.latitude.value) * cos(endRad.longitude.value) - cos(startRad.latitude.value)
      * cos(startRad.longitude.value)
    let y =
      cos(endRad.latitude.value) * sin(endRad.longitude.value) - cos(startRad.latitude.value)
      * sin(startRad.longitude.value)

    return .init(x, y)
  }

  static func crosstrackDistance(from position: Self, to line: Line) -> Measurement<UnitLength> {
    let positionRad = position.radians
    let lineRad = line.map(\.radians)

    let delta13 = acos(
      sin(lineRad.from.latitude.value) * sin(positionRad.latitude.value) + cos(
        lineRad.from.latitude.value
      ) * cos(positionRad.latitude.value)
        * cos(positionRad.longitude.value - lineRad.from.longitude.value)
    )
    let theta13 = atan2(
      sin(positionRad.longitude.value - lineRad.from.longitude.value)
        * cos(positionRad.latitude.value),
      cos(lineRad.from.latitude.value) * sin(positionRad.latitude.value) - sin(
        lineRad.from.latitude.value
      ) * cos(positionRad.latitude.value)
        * cos(positionRad.longitude.value - lineRad.from.longitude.value)
    )
    let theta12 = atan2(
      sin(lineRad.to.longitude.value - lineRad.from.longitude.value)
        * cos(lineRad.to.latitude.value),
      cos(lineRad.from.latitude.value) * sin(lineRad.to.latitude.value) - sin(
        lineRad.from.latitude.value
      ) * cos(lineRad.to.latitude.value)
        * cos(lineRad.to.longitude.value - lineRad.from.longitude.value)
    )
    let deltaXT = asin(sin(delta13) * sin(theta13 - theta12)) * earthRadius

    return .init(value: -deltaXT, unit: .meters)
  }

  func bearing(to coordinate: Self) -> Bearing {
    let startRad = radians
    let endRad = coordinate.radians
    let deltaLon = endRad.longitude.value - startRad.longitude.value
    let y = sin(deltaLon) * cos(endRad.latitude.value)
    let x =
      cos(startRad.latitude.value) * sin(endRad.latitude.value) - sin(startRad.latitude.value)
      * cos(endRad.latitude.value) * cos(deltaLon)
    let initialBearingRad = atan2(y, x)
    let initialBearing = initialBearingRad * 180 / .pi
    let bearingDeg = (initialBearing + 360).truncatingRemainder(dividingBy: 360)
    return .init(angle: bearingDeg, reference: .true)
  }

  func distance(to coordinate: Self) -> Measurement<UnitLength> {
    let startRad = radians
    let endRad = coordinate.radians
    let deltaLat = endRad.latitude.value - startRad.latitude.value
    let deltaLon = endRad.longitude.value - startRad.longitude.value
    let a =
      pow(sin(deltaLat / 2), 2) + cos(startRad.latitude.value) * cos(endRad.latitude.value)
      * pow(sin(deltaLon / 2), 2)
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    let distanceM = earthRadius * c
    return .init(value: distanceM, unit: .meters)
  }

  func offsetBy(bearing: Measurement<UnitAngle>, distance: Measurement<UnitLength>) -> Self {
    // Convert bearing and current location to radians
    let bearingRad = bearing.converted(to: .radians).value
    let distanceFraction = distance.converted(to: .meters).value / earthRadius
    let coordRad = radians

    // Calculate the new latitude
    let newLatitudeRad = asin(
      sin(coordRad.latitude.value) * cos(distanceFraction) + cos(coordRad.latitude.value)
        * sin(distanceFraction) * cos(bearingRad)
    )
    let  // Calculate the new longitude
    newLongitudeRad =
      coordRad.longitude.value
      + atan2(
        sin(bearingRad) * sin(distanceFraction) * cos(coordRad.latitude.value),
        cos(distanceFraction) - sin(coordRad.latitude.value) * sin(newLatitudeRad)
      )

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
    let reciprocal = (degrees + 180).truncatingRemainder(dividingBy: 360)
    let clamped = reciprocal >= 0 ? reciprocal : reciprocal + 360

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
    return .init(angle: angle.value.magnitude, unit: angle.unit, reference: reference)
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
    self.init(
      angle: .init(value: angle, unit: unit),
      reference: reference
    )
  }

  static func - (lhs: Self, rhs: Self) -> Self {
    let angle = lhs.angle - rhs.angle
    let normalized =
      (angle + Measurement(value: 180, unit: .degrees)).converted(to: .degrees).value
      .truncatingRemainder(dividingBy: 360) - 180
    return .init(angle: normalized, reference: .relative)
  }

  func toTrue(declination: Measurement<UnitAngle>) -> Self {
    switch reference {
      case .magnetic:
        .init(angle: angle + declination, reference: .true).normalized
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
        .init(angle: angle - declination, reference: .magnetic).normalized
      case .relative:
        preconditionFailure("Cannot convert relative bearing to magnetic")
    }
  }

  enum Reference: Codable {
    case magnetic, `true`, relative
  }
}
