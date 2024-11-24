import MapKit
import SwiftUI

struct IPSetupView: View {
    @Bindable var target: Target

    var body: some View {
        VStack {
            IPSetupForm(target: target)
            IPSetupMap(target: target)

            HStack {
                NavigationLink(value: SetupFlowStep.targetSetup) {
                    HStack {
                        Image(systemName: "chevron.backward")
                            .accessibilityHidden(true)
                        Text("Define Target")
                    }
                }.accessibilityIdentifier("targetSetupButton")
                Spacer()
                NavigationLink(value: SetupFlowStep.timeOnTarget) {
                    HStack {
                        Text("Time on Target")
                        Image(systemName: "chevron.forward")
                            .accessibilityHidden(true)
                    }
                }.accessibilityIdentifier("timeOnTargetButton")
            }.padding(.horizontal)
        }
    }
}

#Preview {
    let helper = PreviewHelper()
    IPSetupView(target: helper.target())
        .modelContainer(helper.modelContainer)
}
