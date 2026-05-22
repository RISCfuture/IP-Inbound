import SwiftUI

/// The two-line latitude/longitude display with a highlighted cursor character.
/// Tapping a character reports its line and character index back to the caller.
struct LatLonDisplayLines: View {
  private static let fontScale: CGFloat = 0.7
  private static let minimumScaleFactor: CGFloat = 0.5

  let lines: [AttributedString]
  let baseline: CGFloat
  let onTapCharacter: (_ lineIndex: Int, _ charIndex: Int) -> Void

  var body: some View {
    VStack(spacing: 0) {
      ForEach(0..<lines.count, id: \.self) { lineIndex in
        HStack {
          GeometryReader { geo in
            Text(lines[lineIndex])
              .font(.system(size: baseline * Self.fontScale).monospaced())
              .minimumScaleFactor(Self.minimumScaleFactor)
              .lineLimit(1)
              .frame(maxWidth: .infinity, maxHeight: baseline)
              .layoutPriority(1)
              .onTapGesture { location in
                let characterCount = lines[lineIndex].characters.count
                guard characterCount > 0 else { return }
                let widthPerCharacter = geo.size.width / CGFloat(characterCount)
                let charIndex = Int(location.x / widthPerCharacter)
                if charIndex < characterCount {
                  onTapCharacter(lineIndex, charIndex)
                }
              }
              .accessibilityAddTraits(.isButton)
          }
          .frame(idealHeight: baseline)
        }
      }
    }
  }
}

#Preview {
  LatLonDisplayLines(
    lines: [AttributedString("N 37.50000°"), AttributedString("W 121.50000°")],
    baseline: 60,
    onTapCharacter: { _, _ in }
  )
  .padding()
}
