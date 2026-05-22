import SwiftUI

enum SetupFlowStep: Int {
  case targetSetup
  case IPSetup
  case timeOnTarget
  case fly
}

struct SetupFlowView: View {
  @Bindable var target: Target
  var onSelectTarget: (Target) -> Void = { _ in }
  var onChooseTarget: () -> Void = {}

  @State private var path: [SetupFlowStep]

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
              FlyView(
                target: target,
                onSelectTarget: onSelectTarget,
                onChooseTarget: onChooseTarget
              )
              .onAppear {
                target.isConfigured = true
              }
          }
        }
    }
    .onAppear {
      // Jump straight to the fly view when entering — or re-entering — a target that has already
      // been configured (selected from the list, or chosen via the post-pass screen's “Fly next
      // target”). Attached to the `NavigationStack` rather than its root content so it fires on flow
      // entry, not each time the user navigates back to the root within the flow — which would
      // otherwise pull them out of the setup screens while reconfiguring.
      if target.isConfigured && path.last != .fly {
        path = [.fly]
      }
    }
  }

  init(
    target: Target,
    onSelectTarget: @escaping (Target) -> Void = { _ in },
    onChooseTarget: @escaping () -> Void = {}
  ) {
    self.target = target
    self.onSelectTarget = onSelectTarget
    self.onChooseTarget = onChooseTarget
    _path = State(initialValue: target.isConfigured ? [.fly] : [.targetSetup])
  }
}

#Preview {
  let helper = PreviewHelper()
  SetupFlowView(target: helper.target())
    .modelContainer(helper.modelContainer)
}
