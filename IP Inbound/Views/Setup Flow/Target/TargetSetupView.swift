import Defaults
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
        Label("Define IP", systemImage: "chevron.forward")
          .labelStyle(TrailingIconLabelStyle())
      }.accessibilityIdentifier("defineIPButton")
    }
    .padding(.horizontal)
  }
}

private struct TrailingIconLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack {
      configuration.title
      configuration.icon
        .accessibilityHidden(true)
    }
  }
}

#Preview {
  let helper = PreviewHelper()
  NavigationStack {
    TargetSetupView(target: helper.target())
  }
  .modelContainer(helper.modelContainer)
}
