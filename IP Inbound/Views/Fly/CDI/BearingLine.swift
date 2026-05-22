import SwiftUI

struct BearingLine: Shape {
  var deflection: CGFloat?  // fraction of radius
  var maxDeflection = 0.75  // fraction of radius, represents 100% deflection

  // Fractions of radius
  private let inset = 0.1,
    deviationSegmentSize = 0.6,
    arrowheadInset = 0.15

  private let arrowheadSizePoints: CGFloat = 10

  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2
    let maxDeflection = radius * self.maxDeflection
    let deflection = self.deflection.map { maxDeflection * $0 }

    var path = Path()

    // Top fixed portion
    path.move(to: CGPoint(x: center.x, y: center.y - radius * (1 - inset)))
    path.addLine(to: CGPoint(x: center.x, y: center.y - radius * deviationSegmentSize / 2))

    // Center deflected portion
    if let deflection {
      path.move(
        to: CGPoint(x: center.x + deflection, y: center.y - radius * deviationSegmentSize / 2)
      )
      path.addLine(
        to: CGPoint(x: center.x + deflection, y: center.y + radius * deviationSegmentSize / 2)
      )
    }

    // Bottom fixed portion
    path.move(to: CGPoint(x: center.x, y: center.y + radius * deviationSegmentSize / 2))
    path.addLine(to: CGPoint(x: center.x, y: center.y + radius * (1 - inset)))

    // Arrowhead
    path.move(to: CGPoint(x: center.x, y: center.y - radius * (1 - inset)))
    path.addLine(
      to: CGPoint(x: center.x - arrowheadSizePoints, y: center.y - radius * (1 - arrowheadInset))
    )
    path.move(to: CGPoint(x: center.x, y: center.y - radius * (1 - inset)))
    path.addLine(
      to: CGPoint(x: center.x + arrowheadSizePoints, y: center.y - radius * (1 - arrowheadInset))
    )

    return path
  }
}
