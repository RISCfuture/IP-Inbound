import SwiftUI

/// A single tappable, monospaced line of a formatted coordinate with a highlighted
/// cursor character. Tapping a character reports its index back to the caller.
struct CoordinateDisplayLine: View {
  private static let fontScale: CGFloat = 0.6
  private static let minimumScaleFactor: CGFloat = 0.5
  private static let lineHeightScale: CGFloat = 1.5

  let text: AttributedString
  let baseline: CGFloat
  let characterCount: Int
  let onTapCharacter: (Int) -> Void

  var body: some View {
    HStack {
      GeometryReader { geo in
        Text(text)
          .font(.system(size: baseline * Self.fontScale).monospaced())
          .minimumScaleFactor(Self.minimumScaleFactor)
          .lineLimit(1)
          .frame(maxWidth: .infinity, maxHeight: baseline * Self.lineHeightScale)
          .layoutPriority(1)
          .onTapGesture { location in
            guard characterCount > 0 else { return }
            let widthPerCharacter = geo.size.width / CGFloat(characterCount)
            let charIndex = Int(location.x / widthPerCharacter)
            if charIndex < characterCount {
              onTapCharacter(charIndex)
            }
          }
          .accessibilityAddTraits(.isButton)
      }
      .frame(idealHeight: baseline * Self.lineHeightScale)
    }
  }
}

#Preview {
  CoordinateDisplayLine(
    text: AttributedString("12S AB 12345 67890"),
    baseline: 60,
    characterCount: 18,
    onTapCharacter: { _ in }
  )
  .padding()
}
