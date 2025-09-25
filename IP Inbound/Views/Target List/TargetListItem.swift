import Defaults
import SwiftUI

struct TargetListItem: View {
  var target: Target
  @Binding var selectedTarget: Target?

  @Default(.TOTDisplayMode)
  private var displayMode

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(target.name)
        if let coordinate = format(coordinate: target.coordinate) {
          Text(coordinate)
            .foregroundStyle(.secondary)
            .font(.caption)
        }
      }

      Spacer()

      if let timeOnTarget = target.timeOnTarget {
        switch displayMode {
        case .local:
          Text(timeOnTarget, format: localTOTFormatStyle)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("timeOnTarget")
        case .zulu:
          Text(timeOnTarget, format: zuluTOTFormatStyle)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("timeOnTarget")
        }
      }

      Image(systemName: "chevron.forward")
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel("Edit Target")
    }.onTapGesture { selectedTarget = target }
      .accessibilityIdentifier("targetListItem")
      .accessibilityAddTraits(.isLink)
  }
}

#Preview {
  @Previewable @State var selectedTarget: Target?
  let helper = PreviewHelper()

  List {
    TargetListItem(target: helper.target(), selectedTarget: $selectedTarget)
  }
}
