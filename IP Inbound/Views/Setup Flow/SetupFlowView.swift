import SwiftUI

enum SetupFlowStep: Int {
    case targetSetup
    case IPSetup
    case timeOnTarget
    case fly
}

struct SetupFlowView: View {
    @Bindable var target: Target
    @State private var path: [SetupFlowStep] = [.targetSetup]
    @State private var skipToFly = false

    var body: some View {
        NavigationStack(path: $path) {
            TargetSetupView(target: target)
                .navigationTitle("Define Target")
                .navigationDestination(for: SetupFlowStep.self) { step in
                    switch step {
                        case .targetSetup:
                            TargetSetupView(target: target)
                                .navigationTitle("Define Target")
                        case .IPSetup:
                            IPSetupView(target: target)
                                .navigationTitle("Define IP")
                        case .timeOnTarget:
                            TOTSetupView(target: target)
                                .navigationTitle("Time on Target")
                        case .fly:
                            FlyView(target: target)
                                .onAppear {
                                    target.isConfigured = true
                                }
                    }
                }
                .onAppear {
                    // Only skip to fly if this is the initial navigation (meaning we just selected from list)
                    // and not when using the back button (which would have a different path)
                    if target.isConfigured && !skipToFly && path.count == 1 && path.first == .targetSetup {
                        skipToFly = true
                        path = [.fly]
                    }
                }
        }
    }
}

#Preview {
    let helper = PreviewHelper()
    SetupFlowView(target: helper.target())
        .modelContainer(helper.modelContainer)
}
