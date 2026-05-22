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
          Label("Define Target", systemImage: "chevron.backward")
            .labelStyle(.titleAndIcon)
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
