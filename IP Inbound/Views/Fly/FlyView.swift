import CoreLocation
import MeasurementKitLocation
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
      // A fix carrying no usable ground speed or course has no run-in geometry to solve, so the
      // guidance falls back to the countdown until one arrives. Its readouts are drawn from the
      // position and the target, which every fix supplies.
      let math = IPTargetMath(location: location, target: target, now: services.clock.now)
      let guidanceHelper = math.map { GuidanceHelper(math: $0, location: location, target: target) }
      let guidance = guidanceHelper?.guidance ?? .countdownOnly
      let isPastTarget = guidanceHelper?.isPastTarget ?? false

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
          GuidanceContentView(
            math: math,
            coordinate: location.geoCoordinate,
            target: target,
            guidance: guidance,
            courseDeviation: guidanceHelper?.courseDeviation,
            event: event
          )
        }
      }
      .onChange(of: isPastTarget, initial: true) {
        if isPastTarget { postPassResult.recordCrossing(at: services.clock.now) }
      }
      .onChange(of: guidance, initial: true) {
        capturePostPassIfNeeded(guidance: guidance)
      }
    }
    // The Fly screen is a container of separately readable elements, not one element itself.
    // Declaring that keeps the identifier on the container; without it the identifier is applied to
    // every descendant, replacing the ones the readouts set for themselves.
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("flyView")
    .onAppear {
      target.isConfigured = true
      UIApplication.shared.isIdleTimerDisabled = true
      WatchSessionController.shared.update(flying: target)
      LiveActivityController.shared.update(flying: target)
    }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
      WatchSessionController.shared.update(flying: nil)
      LiveActivityController.shared.update(flying: nil)
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
