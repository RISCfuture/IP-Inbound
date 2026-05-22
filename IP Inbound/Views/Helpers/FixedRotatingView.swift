import SwiftUI

/// Animates rotation to a target angle while avoiding the jump that occurs when interpolated values
/// cross the 0°/360° boundary, by always turning through the shortest direction.
struct FixedRotatingView<Content: View>: View {
  private static var rotationDuration: Double { 0.3 }

  let targetAngle: Double
  let content: (Double) -> Content

  @State private var currentAngle: Double = 0

  var body: some View {
    content(currentAngle)
      .onAppear {
        currentAngle = targetAngle.normalizedAngle
      }
      .onChange(of: targetAngle) {
        let normalizedTarget = targetAngle.normalizedAngle
        let delta = currentAngle.shortestAngle(to: normalizedTarget)
        withAnimation(.linear(duration: Self.rotationDuration)) {
          currentAngle += delta
        }
      }
  }
}

#Preview {
  @Previewable @State var targetAngle = 0.0

  FixedRotatingView(targetAngle: targetAngle) { angle in
    Image(systemName: "chevron.up")
      .font(.system(size: 64))
      .rotationEffect(.degrees(angle))
      .accessibilityHidden(true)
  }
  .task {
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(1))
      targetAngle += 90
    }
  }
}

extension Double {
  fileprivate var normalizedAngle: Double {
    let mod = self.truncatingRemainder(dividingBy: 360)
    return mod >= 0 ? mod : mod + 360
  }

  fileprivate func shortestAngle(to target: Double) -> Double {
    let delta = target - self
    let modDelta = delta.truncatingRemainder(dividingBy: 360)
    if modDelta > 180 {
      return modDelta - 360
    }
    if modDelta < -180 {
      return modDelta + 360
    }
    return modDelta
  }
}
