import CoreLocation
import SwiftData
import SwiftUI

struct NewTargetButton: View {
  @Binding var selectedTarget: Target?

  @Environment(\.modelContext)
  private var modelContext

  @Environment(\.previewLocation)
  private var previewLocation

  @Environment(\.services)
  private var services

  @State private var isCreating = false

  var body: some View {
    Button {
      guard !isCreating else { return }
      isCreating = true
      Task {
        defer { isCreating = false }
        let target = Target(
          name: String(localized: "New Target"),
          coordinate: await resolvedCoordinate()
        )
        modelContext.insert(target)
        selectedTarget = target
      }
    } label: {
      Label("Add Target", systemImage: "plus")
    }
    .disabled(isCreating)
    .accessibilityIdentifier("addTargetButton")
  }

  /// The seed coordinate for a new target: the current location when a fresh fix is available,
  /// otherwise Null Island. Creating a target never requires a location — the user enters the real
  /// coordinates next.
  private func resolvedCoordinate() async -> Coordinate {
    if let previewCoordinate = previewLocation?.location?.coordinate {
      return .init(previewCoordinate)
    }
    if let currentCoordinate = await services.location.currentEvent()?.location?.coordinate {
      return .init(currentCoordinate)
    }
    return .init(latitude: 0, longitude: 0)
  }
}

#Preview {
  let helper = PreviewHelper()
  NewTargetButton(selectedTarget: .constant(helper.target()))
    .modelContainer(helper.modelContainer)
    .environment(\.previewLocation, helper.preIPEvent)
}
