import SwiftData
import SwiftUI

struct TargetListView: View {
  @Environment(\.modelContext)
  private var modelContext

  @State private var selectedTarget: Target?
  @State private var targetToFly: Target.ID?
  @State private var showingTutorial = false

  /// The columns shown when the Fly screen is not. Both rather than `.automatic`, which, once bound,
  /// shows only the detail on an iPhone with the width for both.
  @State private var columnVisibility = NavigationSplitViewVisibility.doubleColumn
  @State private var showsFlyScreen = false

  /// Bumped for every request `TargetNavigator` delivers, so the setup flow is rebuilt even when the
  /// request is for the target already showing. `SetupFlowView` lays out its navigation stack only
  /// in its initializer, so "fly the target on screen" means a new flow, not a changed one.
  @State private var navigationRequestCount = 0

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

  /// The sidebar has no part in a run, and beside the Fly screen it takes width the instrument, sized
  /// to the narrower of the detail column's sides, would otherwise use. It stays hidden for as long as
  /// the Fly screen is up, whatever collapsing or expanding the split view would make of it, and
  /// leaving the Fly screen brings back the columns that were showing before.
  private var shownColumns: Binding<NavigationSplitViewVisibility> {
    Binding(
      get: { showsFlyScreen ? .detailOnly : columnVisibility },
      set: { newValue in
        if !showsFlyScreen { columnVisibility = newValue }
      }
    )
  }

  var body: some View {
    NavigationSplitView(columnVisibility: shownColumns) {
      TargetListSidebar(
        selectedTarget: sidebarSelection,
        showingTutorial: $showingTutorial
      )
      .toolbar(removing: showsFlyScreen ? .sidebarToggle : nil)
    } detail: {
      Group {
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
          .id(navigationRequestCount)
        } else {
          Text("No Target").foregroundStyle(.secondary)
        }
      }
      .onPreferenceChange(ShowsFlyScreenKey.self) { [$showsFlyScreen] showsFlyScreen in
        $showsFlyScreen.wrappedValue = showsFlyScreen
      }
    }
    .sheet(isPresented: $showingTutorial) {
      TutorialView()
    }
    .onChange(of: TargetNavigator.shared.pending, initial: true) {
      followNavigationRequest()
    }
  }

  /// - Parameter resumedTarget: a target whose run outlived the last process, opened straight onto
  ///   the Fly screen. Seeded here rather than applied later because `SetupFlowView` lays out its
  ///   navigation stack in its own initializer, so the intent has to be in hand before it is built.
  init(resumedTarget: Target? = nil) {
    _selectedTarget = State(initialValue: resumedTarget)
    _targetToFly = State(initialValue: resumedTarget?.id)
  }

  private func followNavigationRequest() {
    guard let request = TargetNavigator.shared.takePending(),
      let target = target(identifiedBy: request.targetID)
    else { return }
    navigationRequestCount += 1
    targetToFly = request.flying ? target.id : nil
    selectedTarget = target
  }

  private func target(identifiedBy id: Target.ID) -> Target? {
    var descriptor = FetchDescriptor<Target>(predicate: #Predicate { $0.id == id })
    descriptor.fetchLimit = 1
    return try? modelContext.fetch(descriptor).first
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
