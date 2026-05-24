import CoreGraphics

extension CGSize {
  var center: CGPoint { .init(x: width / 2, y: height / 2) }
  var minDimension: CGFloat { min(width, height) }
}

extension CGRect {
  var center: CGPoint { .init(x: midX, y: midY) }
}

extension String {
  func slice(_ index: Int) -> Substring {
    slice(index...index)
  }

  func slice<T: BinaryInteger>(_ range: ClosedRange<T>) -> Substring {
    let start = index(startIndex, offsetBy: Int(range.lowerBound))
    let end = index(startIndex, offsetBy: Int(range.upperBound))
    return self[start...end]
  }
}
