import SwiftUI

struct FixedRotatingView<Content: View>: View {
    // Fixes rotation errors caused by interpolating values that cross 0°/360°

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
                withAnimation(.linear(duration: 0.3)) {
                    currentAngle += delta
                }
            }
    }
}

private extension Double {
    var normalizedAngle: Double {
        let mod = self.truncatingRemainder(dividingBy: 360)
        return mod >= 0 ? mod : mod + 360
    }

    func shortestAngle(to target: Double) -> Double {
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
