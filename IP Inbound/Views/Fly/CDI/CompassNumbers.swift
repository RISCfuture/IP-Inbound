import SwiftUI

struct CompassNumbers: View {
  var rotation: Double
  var increments = 30  // degrees

  private let textInset = 0.8  // fraction of radius
  private var count: Int { 360 / increments }

  @State private var positions: [CachedPosition] = []

  var body: some View {
    GeometryReader { geometry in
      let center = geometry.size.center
      let radius = geometry.size.minDimension / 2

      ZStack {
        ForEach(positions) { position in
          Text(position.text)
            .rotationEffect(.degrees(rotation))
            .position(x: position.x, y: position.y)
            .fontWeight(.bold)
            .foregroundStyle(Color.accentColor)
            .accessibilityHidden(true)
        }
      }
      .onAppear {
        calculatePositions(center: center, radius: radius)
      }
      .onChange(of: geometry.size) {
        calculatePositions(center: center, radius: radius)
      }
    }
  }

  private func calculatePositions(center: CGPoint, radius: CGFloat) {
    positions = (0..<count).map { index in
      let angle = Angle(degrees: Double(index) * Double(increments) - 90).radians
      let x = center.x + cos(angle) * (radius * textInset)
      let y = center.y + sin(angle) * (radius * textInset)
      return CachedPosition(
        id: index,
        x: x,
        y: y,
        text: (index * increments).formatted()
      )
    }
  }

  // Cache compass number positions to avoid recalculation in every render
  private struct CachedPosition: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let text: String
  }
}

#Preview {
  CompassNumbers(rotation: 0)
    .frame(width: 300, height: 300)
    .padding()
}
