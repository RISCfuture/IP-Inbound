import CoreLocation
import SwiftData
import SwiftUI

struct TargetListView: View {
  @State private var selectedTarget: Target?
  @State private var targetToFly: Target.ID?
  @State private var showingTutorial = false

  /// Picking a target from the sidebar always lands on the setup flow, so clear any pending
  /// fly-immediately intent left by the post-pass “Fly” shortcut.
  private var sidebarSelection: Binding<Target?> {
    Binding(
      get: { selectedTarget },
      set: { newValue in
        targetToFly = nil
        selectedTarget = newValue
      }
    )
  }

  var body: some View {
    RequiresLocation {
      NavigationSplitView {
        TargetListSidebar(
          selectedTarget: sidebarSelection,
          showingTutorial: $showingTutorial
        )
      } detail: {
        if let selectedTarget {
          SetupFlowView(
            target: selectedTarget,
            startAtFly: selectedTarget.id == targetToFly,
            onSelectTarget: { selected in
              selected.isConfigured = true
              targetToFly = selected.id
              self.selectedTarget = selected
            },
            onChooseTarget: {
              targetToFly = nil
              self.selectedTarget = nil
            }
          )
          .id(selectedTarget.id)
        } else {
          Text("No Target").foregroundStyle(.secondary)
        }
      }
    }
    .sheet(isPresented: $showingTutorial) {
      TutorialView()
    }
  }
}

#Preview("With Targets") {
  let helper = PreviewHelper()
  TargetListView()
    .modelContainer(helper.modelContainer)
    .onAppear { helper.createTarget() }
}

#Preview("No Selection") {
  let helper = PreviewHelper()
  TargetListView()
    .modelContainer(helper.modelContainer)
}
