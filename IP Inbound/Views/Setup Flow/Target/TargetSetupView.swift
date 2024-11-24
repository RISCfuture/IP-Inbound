import Defaults
import LocationFormatter
import MapKit
import SwiftUI

struct TargetSetupView: View {
    @Bindable var target: Target

    var body: some View {
        TargetSetupForm(target: target)
        TargetSetupMap(target: target)

        HStack {
            Spacer()
            NavigationLink(value: SetupFlowStep.IPSetup) {
                HStack {
                    Text("Define IP")
                    Image(systemName: "chevron.forward")
                        .accessibilityHidden(true)
                }
            }.accessibilityIdentifier("defineIPButton")
        }
        .padding(.horizontal)
    }
}

#Preview {
    let helper = PreviewHelper()
    TargetSetupView(target: helper.target())
        .modelContainer(helper.modelContainer)
}
