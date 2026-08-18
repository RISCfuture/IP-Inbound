import CoreLocation
import Defaults
import Foundation
import SwiftData

@Model
final class Target: CustomDebugStringConvertible, Identifiable, Equatable, Hashable {
  var id = UUID().uuidString
  var name = "New Target"
  var latitude = 0.0
  var longitude = 0.0

  private var _offsetBearing = 0.0  // deg
  var offsetBearing: Double {
    get { _offsetBearing }
    set {
      _offsetBearing =
        newValue >= 0
        ? newValue.truncatingRemainder(dividingBy: 360)
        : (newValue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
  }

  var offsetBearingIsTrue = false

  var offsetDistance = 4.0  // NM
  var offsetTime = 2.0  // min

  var targetGroundSpeed = 120.0  // kts
  var timeOnTarget: Date?
  var isConfigured = false

  var declination = 0.0  // magnetic declination, deg
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
      .init(
        angle: offsetBearing,
        reference: offsetBearingIsTrue ? .true : .magnetic
      )
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

  var debugDescription: String {
    return
      "<Target “\(name)”: \(coordinate); \(offsetBearing)/\(offsetDistance)NM (\(offsetTime)min)>"
  }

  init(
    name: String,
    coordinate: Coordinate
  ) {
    self.name = name
    self.coordinate = coordinate
    targetGroundSpeed = Defaults[.defaultGroundSpeed]

    // The offset's two representations are derived from each other so they stay consistent; unlike
    // `setOffset(…)`, neither is rounded here — the configured default is stored as given.
    switch Defaults[.defaultOffsetType] {
      case .distance:
        offsetDistanceMeasurement = .init(value: Defaults[.defaultOffset], unit: .nauticalMiles)
        offsetTimeMeasurement = offsetDistanceMeasurement / targetGroundSpeedMeasurement
      case .time:
        offsetTimeMeasurement = .init(value: Defaults[.defaultOffset], unit: .minutes)
        offsetDistanceMeasurement = targetGroundSpeedMeasurement * offsetTimeMeasurement
    }

    calculateDeclination()
  }

  static func == (lhs: Target, rhs: Target) -> Bool {
    lhs.id == rhs.id
  }

  /// Sets the offset from a time, rounded to a whole minute. The distance is
  /// re-derived from the rounded time so the two representations stay
  /// consistent and timing matches the displayed value exactly.
  func setOffset(time: Measurement<UnitDuration>) {
    let wholeTime = Measurement(
      value: time.converted(to: .minutes).value.rounded(),
      unit: UnitDuration.minutes
    )
    offsetTimeMeasurement = wholeTime
    offsetDistanceMeasurement = targetGroundSpeedMeasurement * wholeTime
  }

  /// Sets the offset from a distance, rounded to a whole unit of the supplied
  /// measurement. The time is re-derived from the rounded distance so the two
  /// representations stay consistent and timing matches the displayed value
  /// exactly.
  func setOffset(distance: Measurement<UnitLength>) {
    let wholeDistance = Measurement(value: distance.value.rounded(), unit: distance.unit)
    offsetDistanceMeasurement = wholeDistance
    offsetTimeMeasurement = wholeDistance / targetGroundSpeedMeasurement
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  func calculateDeclination() {
    declination = Geomagnetism(longitude: longitude, latitude: latitude).declination
  }
}
