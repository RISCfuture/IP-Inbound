import SwiftUI

struct LubberLine: Shape {
    private let lineSize = 0.15 // fraction of radius

    func path(in rect: CGRect) -> Path {
        let radius = rect.size.minDimension / 2,
            top = CGPoint(x: rect.midX, y: rect.midY - radius)

        var path = Path()
        path.move(to: top)
        path.addLine(to: .init(x: top.x, y: top.y + radius * lineSize))
        return path
    }
}
