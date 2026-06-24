import CoreLocation
import SwiftUI

struct FlyView: View {
  var target: Target
  var onSelectTarget: (Target) -> Void = { _ in }
  var onChooseTarget: () -> Void = {}

  @Environment(\.errorStore)
  var errorStore

  @Environment(\.services)
  private var services

  @State private var postPassResult = PostPassResult()

  var body: some View {
    NeedsLocationView { location, event in
      let math = IPTargetMath(location: location, target: target, now: services.clock.now)
      let guidanceHelper = GuidanceHelper(math: math, location: location, target: target)
      let guidance = guidanceHelper.guidance
      let isPastTarget = guidanceHelper.isPastTarget

      Group {
        if guidance == .postPass, let capture = postPassResult.capture {
          PostPassView(
            capture: capture,
            currentTarget: target,
            onSelectTarget: { selected in
              postPassResult.reset()
              onSelectTarget(selected)
            },
            onChooseTarget: {
              postPassResult.reset()
              onChooseTarget()
            }
          )
        } else {
          GuidanceContentView(math: math, target: target, guidance: guidance, event: event)
        }
      }
      .onChange(of: isPastTarget, initial: true) {
        if isPastTarget { postPassResult.recordCrossing(at: services.clock.now) }
      }
      .onChange(of: guidance, initial: true) {
        capturePostPassIfNeeded(guidance: guidance)
      }
    }
    .accessibilityIdentifier("flyView")
    .onAppear {
      target.isConfigured = true
      UIApplication.shared.isIdleTimerDisabled = true
      WatchSessionController.shared.update(flying: target)
    }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
      WatchSessionController.shared.update(flying: nil)
    }
  }

  private func capturePostPassIfNeeded(guidance: Guidance) {
    guard guidance == .postPass, let timeOnTarget = target.timeOnTarget else { return }
    postPassResult.capture(
      targetName: target.name,
      timeOnTarget: timeOnTarget,
      now: services.clock.now
    )
  }
}

#Preview("On Ground") {
  let helper = PreviewHelper()
  FlyView(target: helper.target(minutesFromNow: 10))
    .environment(\.previewLocation, helper.groundEvent)
}

#Preview("Pre-IP, Early") {
  let helper = PreviewHelper()
  FlyView(target: helper.target(minutesFromNow: 10))
    .environment(\.previewLocation, helper.preIPEvent)
}

#Preview("Pre-IP, On Time") {
  let helper = PreviewHelper()
  FlyView(target: helper.target(minutesFromNow: 4))
    .environment(\.previewLocation, helper.preIPEvent)
}

#Preview("Pre-IP, Late") {
  let helper = PreviewHelper()
  FlyView(target: helper.target(minutesFromNow: 2))
    .environment(\.previewLocation, helper.preIPEvent)
}

#Preview("IP-to-Target") {
  let helper = PreviewHelper()
  FlyView(target: helper.target(minutesFromNow: 1))
    .environment(\.previewLocation, helper.postIPEvent)
}
