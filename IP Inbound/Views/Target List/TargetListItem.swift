import Defaults
import IP_Inbound_Shared
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

/// A list row's state as the canvas labels it.
private enum TargetListItemPreview: CaseIterable, CustomStringConvertible {
  case withTOT, noTOT, localTime, zuluTime

  var description: String {
    switch self {
      case .withTOT: "With TOT"
      case .noTOT: "No TOT"
      case .localTime: "Local Time"
      case .zuluTime: "Zulu Time"
    }
  }

  func apply(to target: Target) {
    switch self {
      case .withTOT: break
      case .noTOT: target.timeOnTarget = nil
      case .localTime: Defaults[.TOTDisplayMode] = .local
      case .zuluTime: Defaults[.TOTDisplayMode] = .zulu
    }
  }
}

#Preview(arguments: TargetListItemPreview.allCases) { preview in
  let helper = PreviewHelper()
  let target = helper.target()

  List {
    TargetListItem(target: target)
  }
  .onAppear { preview.apply(to: target) }
}
