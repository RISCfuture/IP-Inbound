import CoreLocation
import SwiftData
import SwiftUI

struct NewTargetButton: View {
    @Binding var selectedTarget: Target?
    var location: CLLocation

    @Environment(\.modelContext)
    private var modelContext

    var body: some View {
        Button {
            let target = Target(name: "New Target", coordinate: .init(location.coordinate))
            modelContext.insert(target)
            selectedTarget = target
        } label: {
            Label("Add Target", systemImage: "plus")
        }.accessibilityIdentifier("addTargetButton")
    }
}

#Preview {
    let helper = PreviewHelper()
    NewTargetButton(selectedTarget: .constant(helper.target()), location: PreviewHelper.preIPLocation)
        .modelContainer(helper.modelContainer)
}
