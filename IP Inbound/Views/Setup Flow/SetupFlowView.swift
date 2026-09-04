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
    // Setting a run up is the point at which the pilot has committed to flying one, so it is the
    // point at which the GPS is worth warming and the authorization prompt is worth raising: the
    // Fly screen then opens on a fix already in hand rather than on the acquiring-GPS placeholder.
    // Scoping it here also means the hold is released when the pilot leaves the run — which is what
    // a screen above the window's root can promise and its root cannot.
    .warmsLocation()
  }

  init(
    target: Target,
    startAtFly: Bool = false,
    onSelectTarget: @escaping (Target) -> Void = { _ in },
    onChooseTarget: @escaping () -> Void = {}
  ) {
    self.target = target
    self.onSelectTarget = onSelectTarget
    self.onChooseTarget = onChooseTarget
    _path = State(initialValue: startAtFly ? [.fly] : [.targetSetup])
  }
}

#Preview {
  let helper = PreviewHelper()
  SetupFlowView(target: helper.target())
    .modelContainer(helper.modelContainer)
}
