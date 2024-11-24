import CoreLocation
import SwiftData
import SwiftUI

struct TargetListView: View {
    @Query(sort: \Target.name)
    private var targets: [Target]

    @State private var selectedTarget: Target?
    @State private var showingTutorial = false

    @Environment(\.modelContext)
    private var modelContext

    var body: some View {
        NeedsLocationView { location, _ in
            NavigationSplitView {
                Group {
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
                            NewTargetButton(selectedTarget: $selectedTarget, location: location)
                            Spacer()
                            Button {
                                showingTutorial = true
                            } label: {
                                Label("Tutorial", systemImage: "questionmark.circle")
                            }.accessibilityIdentifier("tutorialButton")
                        }.padding()
                    }
                }.navigationTitle("Targets")
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
