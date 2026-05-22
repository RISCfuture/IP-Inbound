import SwiftUI

/// Supplementary readouts beneath the main TOT display: the time in the alternate reference frame
/// (Zulu or target local) and a relative description of how far away the TOT is.
struct TOTSecondaryInfoView: View {
  private static let lineSpacing = 4.0

  let entryManager: TOTEntryManager

  var body: some View {
    VStack(spacing: Self.lineSpacing) {
      Text(entryManager.secondaryTimeString)
        .font(.headline)
        .foregroundStyle(.secondary)

      Text(entryManager.relativeTimeString)
        .font(.headline)
        .foregroundStyle(.secondary)
    }
  }
}

#Preview {
  let coordinate = Coordinate(latitude: 37.5, longitude: -121.5)
  let manager = TOTEntryManager(
    timeOnTarget: Date().addingTimeInterval(30 * 60),
    targetCoordinate: coordinate
  )

  TOTSecondaryInfoView(entryManager: manager)
    .padding()
}
