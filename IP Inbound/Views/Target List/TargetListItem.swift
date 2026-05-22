import Defaults
import SwiftUI

struct TargetListItem: View {
  var target: Target
  @Binding var selectedTarget: Target?

  @Default(.TOTDisplayMode)
  private var displayMode

  private var formattedTimeOnTarget: String? {
    guard let timeOnTarget = target.timeOnTarget else { return nil }
    switch displayMode {
      case .local:
        return timeOnTarget.formatted(localTOTFormatStyle)
      case .zulu:
        return timeOnTarget.formatted(zuluTOTFormatStyle)
    }
  }

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

      if let formattedTimeOnTarget {
        Text(formattedTimeOnTarget)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("timeOnTarget")
      }

      Image(systemName: "chevron.forward")
        .foregroundStyle(.secondary)
        .accessibilityLabel(Text("Edit Target"))
    }.onTapGesture { selectedTarget = target }
      .accessibilityIdentifier("targetListItem")
      .accessibilityAddTraits(.isLink)
  }
}

#Preview("With TOT") {
  @Previewable @State var selectedTarget: Target?
  let helper = PreviewHelper()

  List {
    TargetListItem(target: helper.target(), selectedTarget: $selectedTarget)
  }
}

#Preview("No TOT") {
  @Previewable @State var selectedTarget: Target?
  let helper = PreviewHelper()
  let target = helper.target()

  List {
    TargetListItem(target: target, selectedTarget: $selectedTarget)
  }
  .onAppear { target.timeOnTarget = nil }
}

#Preview("Local Time") {
  @Previewable @State var selectedTarget: Target?
  let helper = PreviewHelper()

  List {
    TargetListItem(target: helper.target(), selectedTarget: $selectedTarget)
  }
  .onAppear { Defaults[.TOTDisplayMode] = .local }
}

#Preview("Zulu Time") {
  @Previewable @State var selectedTarget: Target?
  let helper = PreviewHelper()

  List {
    TargetListItem(target: helper.target(), selectedTarget: $selectedTarget)
  }
  .onAppear { Defaults[.TOTDisplayMode] = .zulu }
}
