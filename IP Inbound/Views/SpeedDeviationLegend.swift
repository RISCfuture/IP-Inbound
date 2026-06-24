import SwiftUI

/// Legend used in the tutorial to explain the color/symbol scale of the in-flight speed deviation
/// indicator, from “too slow” through “on time” to “too fast”. The bright asset colors are
/// intentional: the legend exists to explain that color scale.
struct SpeedDeviationLegend: View {
  private static let rowVerticalPadding: CGFloat = 8
  private static let symbolHorizontalPadding: CGFloat = 4
  private static let rowCornerRadius: CGFloat = 8
  private static let legendCornerRadius: CGFloat = 12

  var body: some View {
    VStack {
      ForEach(TimingTier.allCases, id: \.self) { tier in
        Label {
          Text(label(for: tier))
            .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
          Image(systemName: tier.systemImage)
            .foregroundStyle(tier.color)
            .accessibilityHidden(true)
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

  private func label(for tier: TimingTier) -> LocalizedStringKey {
    switch tier {
      case .tooSlowWarning: "Too slow"
      case .tooSlowCaution: "Slightly slow"
      case .onTime: "On time"
      case .tooFastCaution: "Slightly fast"
      case .tooFastWarning: "Too fast"
    }
  }
}

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
