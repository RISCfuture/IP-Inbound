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
    .sheet(isPresented: $showingTutorial) {
      TutorialView()
    }
  }

  /// - Parameter resumedTarget: a target whose run outlived the last process, opened straight onto
  ///   the Fly screen. Seeded here rather than applied later because `SetupFlowView` lays out its
  ///   navigation stack in its own initializer, so the intent has to be in hand before it is built.
  init(resumedTarget: Target? = nil) {
    _selectedTarget = State(initialValue: resumedTarget)
    _targetToFly = State(initialValue: resumedTarget?.id)
  }
}

#Preview("With Targets") {
  let helper = PreviewHelper()
  TargetListView()
    .modelContainer(helper.modelContainer)
    .environment(\.previewLocation, helper.preIPEvent)
    .onAppear { helper.createTargets() }
}

#Preview("No Selection") {
  let helper = PreviewHelper()
  TargetListView()
    .modelContainer(helper.modelContainer)
    .environment(\.previewLocation, helper.preIPEvent)
}
