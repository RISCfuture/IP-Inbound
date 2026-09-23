import AppIntents
import SwiftData
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

  /// Whether the flow still owes the Fly screen it was asked to open on. It is owed until that
  /// screen has appeared: until then an empty path is the split view's doing, and after it, the
  /// pilot's.
  @State private var owesFlyScreen: Bool

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
                owesFlyScreen = false
              }
          }
        }
    }
    // A collapsed split view empties the path of a stack it pushes as its detail, after the
    // initializer has laid that path out, and how soon after depends on how the app was brought
    // forward. A flow asked to open on the Fly screen while the target list is showing — as a Siri
    // request is, on iPhone — would otherwise open at its start.
    .onChange(of: path, initial: true, restoreOwedFlyScreen)
    // Every screen of the flow is about this one target, so Siri can take it as the one on screen.
    .appEntityIdentifier(.target(target.id))
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
    _owesFlyScreen = State(initialValue: startAtFly)
  }

  private func restoreOwedFlyScreen() {
    guard owesFlyScreen, path.isEmpty else { return }
    // The split view empties the path mid-update, and a push made inside that update is dropped.
    Task { path = [.fly] }
  }
}

#Preview {
  let helper = PreviewHelper()
  SetupFlowView(target: helper.target())
    .modelContainer(helper.modelContainer)
}
