import CoreGraphics

extension CGSize {
    var center: CGPoint { .init(x: width / 2, y: height / 2) }
    var minDimension: CGFloat { min(width, height) }
    var maxDimension: CGFloat { max(width, height) }
}

extension CGRect {
    var center: CGPoint { .init(x: midX, y: midY) }
}

extension CGPoint {
    func offset(dx: CGFloat = 0, dy: CGFloat = 0) -> CGPoint {
        .init(x: x + dx, y: y + dy)
    }
}

extension String {
    func slice(_ index: Int) -> Substring {
        slice(index...index)
    }

    func slice<T: BinaryInteger>(_ range: ClosedRange<T>) -> Substring {
        let start = index(startIndex, offsetBy: Int(range.lowerBound)),
            end = index(startIndex, offsetBy: Int(range.upperBound))
        return self[start...end]
    }
}
