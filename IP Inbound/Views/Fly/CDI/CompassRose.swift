import CoreGraphics
import SwiftUI

struct CompassRose: Shape {
  var minorTickInterval = 5  // degrees
  var majorTickInterval = 10  // degrees, must be a multiple of minorTickInterval

  // Fractions of radius
  private let majorTickInset = 0.9,
    minorTickInset = 0.95

  func path(in rect: CGRect) -> Path {
    let center = rect.center
    let radius = rect.size.minDimension / 2

    var path = Path()

    for degree in stride(from: 0, to: 360, by: minorTickInterval) {
      let angle = Angle(degrees: Double(degree)).radians
      let tickEnd = CGPoint(
        x: center.x + cos(angle) * radius,
        y: center.y + sin(angle) * radius
      )
      let tickStart =
        if degree.isMultiple(of: majorTickInterval) {
          CGPoint(
            x: center.x + cos(angle) * (radius * majorTickInset),
            y: center.y + sin(angle) * (radius * majorTickInset)
          )
        } else {
          CGPoint(
            x: center.x + cos(angle) * (radius * minorTickInset),
            y: center.y + sin(angle) * (radius * minorTickInset)
          )
        }

      path.move(to: tickStart)
      path.addLine(to: tickEnd)
    }

    return path
  }
}
