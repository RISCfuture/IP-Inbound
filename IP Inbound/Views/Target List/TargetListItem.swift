import Defaults
import SwiftUI

struct TargetListItem: View {
  var target: Target

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
        .foregroundStyle(.tertiary)
        .font(.caption.weight(.semibold))
        .accessibilityHidden(true)
    }
    .accessibilityIdentifier("targetListItem")
  }
}

#Preview("With TOT") {
  let helper = PreviewHelper()

  List {
    TargetListItem(target: helper.target())
  }
}

#Preview("No TOT") {
  let helper = PreviewHelper()
  let target = helper.target()

  List {
    TargetListItem(target: target)
  }
  .onAppear { target.timeOnTarget = nil }
}

#Preview("Local Time") {
  let helper = PreviewHelper()

  List {
    TargetListItem(target: helper.target())
  }
  .onAppear { Defaults[.TOTDisplayMode] = .local }
}

#Preview("Zulu Time") {
  let helper = PreviewHelper()

  List {
    TargetListItem(target: helper.target())
  }
  .onAppear { Defaults[.TOTDisplayMode] = .zulu }
}
