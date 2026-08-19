import Foundation
import MeasurementKit
import MeasurementKitLocation

extension Coordinate {
  /// The latitude in degrees.
  var latitudeDeg: Double { latitude.degrees }

  /// The longitude in degrees.
  var longitudeDeg: Double { longitude.degrees }

  /// The MGRS/UTM latitude band this coordinate falls in: the polar bands `A` and `Z` outside the
  /// grid's coverage, and one of the twenty eight-degree bands `C` through `X` inside it.
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

  /// The displacement from `start` to `end` on the plane the two points project onto, for the
  /// dot-product tests that only need which side of an axis a point lies on.
  static func vector(from start: Self, to end: Self) -> Vector {
    let x =
      cos(end.latitude.radians) * cos(end.longitude.radians) - cos(start.latitude.radians)
      * cos(start.longitude.radians)
    let y =
      cos(end.latitude.radians) * sin(end.longitude.radians) - cos(start.latitude.radians)
      * sin(start.longitude.radians)

    return .init(x, y)
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
