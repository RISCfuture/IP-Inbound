import CoreLocation
import Defaults
import Foundation

enum DisplayMode: String, Defaults.Serializable {
  case local
  case zulu
}

public struct CoordinateBridge: Defaults.Bridge {
  public typealias Value = CLLocationCoordinate2D
  public typealias Serializable = (Double, Double)

  public func serialize(_ value: CLLocationCoordinate2D?) -> (Double, Double)? {
    guard let value else { return nil }
    return (value.latitude, value.longitude)
  }

  public func deserialize(_ object: (Double, Double)?) -> CLLocationCoordinate2D? {
    guard let object else { return nil }
    return .init(latitude: object.0, longitude: object.1)
  }
}

extension CLLocationCoordinate2D: Defaults.Serializable {
  public typealias Bridge = CoordinateBridge

  public static var bridge: CoordinateBridge { .init() }
}

enum DistanceUnit: String, Defaults.Serializable, CaseIterable {
  case nauticalMiles
  case miles
  case kilometers

  var distanceUnit: UnitLength {
    switch self {
    case .nauticalMiles: .nauticalMiles
    case .miles: .miles
    case .kilometers: .kilometers
    }
  }

  var speedUnit: UnitSpeed {
    switch self {
    case .nauticalMiles: .knots
    case .miles: .milesPerHour
    case .kilometers: .kilometersPerHour
    }
  }
}

extension Defaults.Keys {
  static let defaultGroundSpeed = Key<Double>("defaultGroundSpeed", default: 120)  // kts
  static let defaultOffsetType = Key<IPOffsetType>("defaultOffsetType", default: .distance)
  static let defaultOffset = Key<Double>("defaultOffset", default: 4)  // NM
  static let coordinateFormat = Key<CoordinateFormat>(
    "coordinateFormat", default: .degreesMinutesSeconds)
  static let TOTDisplayMode = Key<DisplayMode>("TOTDisplayMode", default: .zulu)
  static let distanceUnit = Key<DistanceUnit>("distanceUnit", default: .nauticalMiles)
}
