import SwiftUI

// swiftlint:disable accessibility_label_for_image

/// Legend used in the tutorial to explain the color/symbol scale of the in-flight speed deviation
/// indicator, from “too slow” through “on time” to “too fast”. The bright asset colors are
/// intentional: the legend exists to explain that color scale.
struct SpeedDeviationLegend: View {
  private static let rowVerticalPadding: CGFloat = 8
  private static let symbolHorizontalPadding: CGFloat = 4
  private static let rowCornerRadius: CGFloat = 8
  private static let legendCornerRadius: CGFloat = 12

  private static let rows: [Row] = [
    .init(systemImage: "chevron.up.2", colorName: "TooSlowWarning", label: "Too slow"),
    .init(systemImage: "chevron.up", colorName: "TooSlowCaution", label: "Slightly slow"),
    .init(systemImage: "checkmark.circle.fill", colorName: "OnTime", label: "On time"),
    .init(systemImage: "chevron.down", colorName: "TooFastCaution", label: "Slightly fast"),
    .init(systemImage: "chevron.down.2", colorName: "TooFastWarning", label: "Too fast")
  ]

  var body: some View {
    VStack {
      ForEach(Self.rows) { row in
        Label {
          Text(row.label)
            .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
          Image(systemName: row.systemImage)
            .foregroundStyle(Color(row.colorName))
            .padding(.horizontal, Self.symbolHorizontalPadding)
        }
        .padding(.vertical, Self.rowVerticalPadding)
        .background(.thinMaterial)
        .clipShape(.rect(cornerRadius: Self.rowCornerRadius))
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .center)
    .clipShape(.rect(cornerRadius: Self.legendCornerRadius))
  }

  private struct Row: Identifiable {
    let systemImage: String
    let colorName: String
    let label: LocalizedStringKey

    var id: String { colorName }
  }
}

// swiftlint:enable accessibility_label_for_image

#Preview("Light") {
  SpeedDeviationLegend()
    .padding()
    .environment(\.colorScheme, .light)
}

#Preview("Dark") {
  SpeedDeviationLegend()
    .padding()
    .environment(\.colorScheme, .dark)
}
