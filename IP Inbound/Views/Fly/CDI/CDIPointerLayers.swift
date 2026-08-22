import SwiftUI

/// A direct-to chevron (e.g. for the IP or target) positioned around the compass
/// rose and rotated to its relative bearing.
struct CDIDirectPointerLayer: View {
  static let chevronRadiusFraction: CGFloat = 0.8

  let relativeAngle: Double
  let label: String
  let color: Color
  let accessibilityDescription: LocalizedStringResource
  let radius: CGFloat
  let center: CGPoint
  var animatesRotation = false

  var body: some View {
    FixedRotatingView(targetAngle: relativeAngle) { angle in
      DirectPointer(label: label, color: color, accessibilityDescription: accessibilityDescription)
        .position(x: center.x, y: center.y - radius * Self.chevronRadiusFraction)
        .rotationEffect(.degrees(angle), anchor: .center)
        .animation(animatesRotation ? .linear : nil, value: relativeAngle)
        .drawingGroup()
    }
  }
}

/// The bearing pointer and its course-deviation deflection markers, rotated to
/// the relative bearing.
struct CDIBearingPointerLayer: View {
  private static let bearingLineWidth: CGFloat = 5

  let relativeAngle: Double
  let needleOffset: Double?
  let fullScaleRadiusFraction: Double
  let bearingColor: Color

  var body: some View {
    FixedRotatingView(targetAngle: relativeAngle) { angle in
      Group {
        DeflectionMarkers(fullScaleRadiusFraction: fullScaleRadiusFraction)
          .drawingGroup()
        BearingLine(needleOffset: needleOffset, fullScaleRadiusFraction: fullScaleRadiusFraction)
          .stroke(lineWidth: Self.bearingLineWidth)
          .foregroundStyle(bearingColor)
          .drawingGroup()
      }
      .rotationEffect(.degrees(angle))
    }
  }
}
