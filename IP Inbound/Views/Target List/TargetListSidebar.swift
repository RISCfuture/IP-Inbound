import SwiftData
import SwiftUI

struct TargetListSidebar: View {
  @Binding var selectedTarget: Target?
  @Binding var showingTutorial: Bool

  @Query(sort: \Target.name)
  private var targets: [Target]

  @Environment(\.modelContext)
  private var modelContext

  /// Targets without a time on target sort by name at the top, followed by targets with a
  /// time on target in chronological order.
  private var sortedTargets: [Target] {
    targets.sorted { lhs, rhs in
      switch (lhs.timeOnTarget, rhs.timeOnTarget) {
        case let (lhsTOT?, rhsTOT?): lhsTOT < rhsTOT
        case (nil, nil): lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        case (nil, _): true
        case (_, nil): false
      }
    }
  }

  var body: some View {
    List(selection: $selectedTarget) {
      ForEach(sortedTargets, id: \.self) { target in
        TargetListItem(target: target)
      }.onDelete { offsets in
        for offset in offsets {
          delete(sortedTargets[offset])
        }
      }
    }
    .navigationTitle("Targets")
    .toolbar {
      ToolbarItem(placement: .bottomBar) {
        NewTargetButton(selectedTarget: $selectedTarget)
      }
      ToolbarSpacer(.flexible, placement: .bottomBar)
      ToolbarItem(placement: .bottomBar) {
        Button {
          showingTutorial = true
        } label: {
          Label("Tutorial", systemImage: "questionmark.circle")
        }
        .accessibilityIdentifier("tutorialButton")
      }
    }
  }

  /// A deleted target's identifier is read before it goes, because a countdown armed for it outlives
  /// the model and is the app's to take down.
  private func delete(_ target: Target) {
    LiveActivityController.shared.disarm(targetID: target.id)
    modelContext.delete(target)
  }
}

#Preview("With Targets") {
  @Previewable @State var selectedTarget: Target?
  @Previewable @State var showingTutorial = false
  let helper = PreviewHelper()
  NavigationSplitView {
    TargetListSidebar(
      selectedTarget: $selectedTarget,
      showingTutorial: $showingTutorial
    )
  } detail: {
    Text("Detail")
  }
  .modelContainer(helper.modelContainer)
  .onAppear { helper.createTargets() }
}

#Preview("Empty List") {
  @Previewable @State var selectedTarget: Target?
  @Previewable @State var showingTutorial = false
  let helper = PreviewHelper()
  NavigationSplitView {
    TargetListSidebar(
      selectedTarget: $selectedTarget,
      showingTutorial: $showingTutorial
    )
  } detail: {
    Text("Detail")
  }
  .modelContainer(helper.modelContainer)
}
