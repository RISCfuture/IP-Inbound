import CoreLocation
import IP_Inbound_Shared
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

  /// The phase the last fix with geometry to solve put the aircraft in, fed back so the early-arrival
  /// threshold can hold its ground against a lead hovering at the boundary. A fix carrying no usable
  /// ground speed or course leaves it standing: it says nothing about where the run has got to, and
  /// letting it read as the on-ground countdown would drop a hold-off already under way.
  @State private var previousGuidance: Guidance?

  /// The phase for a fix there is no run-in geometry to solve from. The countdown stands until the
  /// tasking lapses, which needs no geometry to judge — and leaving a lapsed run counting down would
  /// hold the screen on a run everything else has already stood down.
  private var guidanceWithoutGeometry: Guidance {
    target.hasRunExpired(at: services.clock.now) ? .postPass : .countdownOnly
  }

  var body: some View {
    NeedsLocationView { location, event in
      // A fix carrying no usable ground speed or course has no run-in geometry to solve, so the
      // guidance falls back to the countdown until one arrives. Its readouts are drawn from the
      // position and the target, which every fix supplies.
      let math = IPTargetMath(location: location, target: target, now: services.clock.now)
      let guidanceHelper = math.map {
        GuidanceHelper(
          math: $0,
          location: location,
          target: target,
          previousGuidance: previousGuidance
        )
      }
      let solvedGuidance = guidanceHelper?.guidance
      let guidance = solvedGuidance ?? guidanceWithoutGeometry
      let isPastTarget = guidanceHelper?.isPastTarget ?? false
      let runIn = math.flatMap(RunInSnapshot.init(math:))

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
      // Only a fix that solved has a phase to carry forward: the countdown a bare fix falls back to
      // is what the screen shows, not a reading of the run.
      .onChange(of: solvedGuidance, initial: true) {
        if let solvedGuidance { previousGuidance = solvedGuidance }
      }
      .onChange(of: guidance, initial: true) {
        capturePostPassIfNeeded(guidance: guidance)
      }
      // `RunInSnapshot` is rounded to the precision the Lock Screen shows, so this fires when the
      // pilot would see the figures move rather than once per fix.
      .onChange(of: runIn, initial: true) {
        LiveActivityController.shared.update(runIn: runIn, for: target)
      }
    }
    // The Fly screen is a container of separately readable elements, not one element itself.
    // Declaring that keeps the identifier on the container; without it the identifier is applied to
    // every descendant, replacing the ones the readouts set for themselves.
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("flyView")
    .onAppear {
      target.isConfigured = true
      RunController.shared.beginRun(flying: target)
    }
    // Flying straight on to the next target replaces this whole screen, and SwiftUI may raise the
    // replacement before it lowers this one. Tearing the run down then would end the run the next
    // target has already begun — raised, or still waiting for its window to open — so the screen
    // only dismantles a run it still owns.
    .onDisappear {
      guard RunController.shared.ownsRun(flying: target) else { return }
      RunController.shared.endRun()
    }
  }

  private func capturePostPassIfNeeded(guidance: Guidance) {
    guard guidance == .postPass, let timeOnTarget = target.timeOnTarget else { return }
    postPassResult.capture(targetName: target.name, timeOnTarget: timeOnTarget)
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
