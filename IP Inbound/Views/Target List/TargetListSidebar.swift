import SwiftData
import SwiftUI

struct TargetListSidebar: View {
  @Binding var selectedTarget: Target?
  @Binding var showingTutorial: Bool

  @Query(sort: \Target.name)
  private var targets: [Target]

  @Environment(\.modelContext)
  private var modelContext

  var body: some View {
    VStack {
      List(selection: $selectedTarget) {
        ForEach(targets, id: \.self) { target in
          TargetListItem(target: target, selectedTarget: $selectedTarget)
        }.onDelete { offsets in
          for offset in offsets {
            modelContext.delete(targets[offset])
          }
        }
      }
      HStack {
        NewTargetButton(selectedTarget: $selectedTarget)
        Spacer()
        Button {
          showingTutorial = true
        } label: {
          Label("Tutorial", systemImage: "questionmark.circle")
        }.accessibilityIdentifier("tutorialButton")
      }.padding()
    }.navigationTitle("Targets")
  }
}

#Preview {
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
  .onAppear { helper.createTarget() }
}
