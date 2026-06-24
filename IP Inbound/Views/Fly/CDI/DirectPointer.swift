import SwiftUI

private struct OpenChevron: Shape {
  func path(in rect: CGRect) -> Path {
    let width = rect.width
    let height = rect.height

    let apex = CGPoint(x: width / 2, y: 0)
    let left = CGPoint(x: 0, y: height)
    let right = CGPoint(x: width, y: height)

    return Path { path in
      path.move(to: apex)
      path.addLine(to: left)
      path.move(to: apex)
      path.addLine(to: right)
    }
  }
}

struct DirectPointer: View {
  private static let chevronLineWidth: CGFloat = 3,
    chevronMiterLimit: CGFloat = 4
  private static let chevronWidth: CGFloat = 40,
    chevronHeight: CGFloat = 25
  private static let labelFontSize: CGFloat = 12
  private static let labelHorizontalPadding: CGFloat = 4,
    labelCornerRadius: CGFloat = 4,
    labelVerticalOffset: CGFloat = 10

  let label: String
  let color: Color
  let accessibilityDescription: LocalizedStringResource

  var body: some View {
    ZStack {
      OpenChevron()
        .stroke(
          color,
          style: .init(
            lineWidth: Self.chevronLineWidth,
            lineCap: .round,
            lineJoin: .miter,
            miterLimit: Self.chevronMiterLimit
          )
        )
        .frame(width: Self.chevronWidth, height: Self.chevronHeight)

      Text(label)
        .font(.system(size: Self.labelFontSize, weight: .black))
        .foregroundStyle(color)
        .padding(.horizontal, Self.labelHorizontalPadding)
        .background(
          RoundedRectangle(cornerRadius: Self.labelCornerRadius).fill(
            Color(.systemBackground)
          )
        )
        .offset(y: Self.labelVerticalOffset)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(accessibilityDescription))
  }
}

#Preview {
  VStack {
    DirectPointer(
      label: "IP",
      color: .yellow,
      accessibilityDescription: "Direction to initial point"
    )
    .padding()
    DirectPointer(
      label: "T",
      color: .red,
      accessibilityDescription: "Direction to target"
    )
    .padding()
  }
}
