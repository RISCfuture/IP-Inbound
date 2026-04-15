import CoreLocation
import SwiftData
import SwiftUI

struct TargetListView: View {
  @State private var selectedTarget: Target?
  @State private var showingTutorial = false

  var body: some View {
    RequiresLocation {
      NavigationSplitView {
        TargetListSidebar(
          selectedTarget: $selectedTarget,
          showingTutorial: $showingTutorial
        )
      } detail: {
        if let selectedTarget {
          SetupFlowView(target: selectedTarget)
        } else {
          Text("No Target").foregroundColor(.secondary)
        }
      }
    }
    .sheet(isPresented: $showingTutorial) {
      TutorialView()
    }
  }
}

#Preview {
  let helper = PreviewHelper()
  TargetListView()
    .modelContainer(helper.modelContainer)
    .onAppear { helper.createTarget() }
}
