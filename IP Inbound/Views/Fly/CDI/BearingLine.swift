import SwiftUI

struct BearingLine: Shape {
  /// Displacement of the deflected segment from center, as a fraction of full-scale travel in
  /// `[-1, 1]`, positive to the right of the course as drawn. `nil` draws the course line with no
  /// deflected segment at all.
  var needleOffset: Double?
  /// Full-scale needle travel, as a fraction of the rose's radius.
  var fullScaleRadiusFraction: Double

  // Fractions of radius
  private let inset = 0.1,
    deviationSegmentSize = 0.6,
    arrowheadInset = 0.15

  private let arrowheadSizePoints: CGFloat = 10

  func path(in rect: CGRect) -> Path {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2
    let travel = radius * fullScaleRadiusFraction
    let offset = needleOffset.map { travel * $0 }

    var path = Path()

    // Top fixed portion
    path.move(to: CGPoint(x: center.x, y: center.y - radius * (1 - inset)))
    path.addLine(to: CGPoint(x: center.x, y: center.y - radius * deviationSegmentSize / 2))

    // Center deflected portion
    if let offset {
      path.move(
        to: CGPoint(x: center.x + offset, y: center.y - radius * deviationSegmentSize / 2)
      )
      path.addLine(
        to: CGPoint(x: center.x + offset, y: center.y + radius * deviationSegmentSize / 2)
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
