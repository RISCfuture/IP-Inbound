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
        guard let coordinate = await resolvedCoordinate() else { return }
        let target = Target(name: String(localized: "New Target"), coordinate: .init(coordinate))
        modelContext.insert(target)
        selectedTarget = target
      }
    } label: {
      Label("Add Target", systemImage: "plus")
    }
    .disabled(isCreating)
    .accessibilityIdentifier("addTargetButton")
  }

  private func resolvedCoordinate() async -> CLLocationCoordinate2D? {
    if let previewCoord = previewLocation?.location?.coordinate {
      return previewCoord
    }
    return await services.location.currentEvent()?.location?.coordinate
  }
}

#Preview {
  let helper = PreviewHelper()
  NewTargetButton(selectedTarget: .constant(helper.target()))
    .modelContainer(helper.modelContainer)
    .environment(\.previewLocation, helper.preIPEvent)
}
