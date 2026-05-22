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
          guidanceContent(math: math, guidance: guidance, event: event)
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
    }
    .onDisappear {
      UIApplication.shared.isIdleTimerDisabled = false
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

  @ViewBuilder
  private func guidanceContent(
    math: IPTargetMath,
    guidance: Guidance,
    event: LocationEvent
  ) -> some View {
    VStack {
      VStack {
        switch guidance {
          case .toIPWithSpeedGuidance, .toIPWithCountdown:
            Text("P.POS → IP").font(.title)
            Text(target.name).font(.caption)
          case .toTarget:
            Text("IP → Target").font(.title)
            Text(target.name).font(.caption)
          case .toTargetBypassingIP:
            Text("P.POS → Target").font(.title).foregroundStyle(Color.red)
            Text(target.name).font(.caption)
          case .countdownOnly, .postPass:
            Text(target.name).font(.title)
        }
      }

      switch guidance {
        case .toIPWithSpeedGuidance, .toIPWithCountdown:
          if let fromTo = math.pposToIP {
            CDIView(
              heading: fromTo.trackMagnetic,
              bearing: fromTo.bearingMagnetic,
              bearingColor: .yellow,
              IPDirectBearing: nil,
              targetDirectBearing: math.pposToTarget?.bearingMagnetic,
              crossTrackDistance: nil
            )
            .accessibilityIdentifier("cdi")
          }
        case .toTarget, .toTargetBypassingIP:
          if let fromTo = math.pposToTarget {
            CDIView(
              heading: fromTo.trackMagnetic,
              bearing: target.desiredTrackMagnetic,
              bearingColor: .red,
              IPDirectBearing: math.pposToIP?.bearingMagnetic,
              targetDirectBearing: math.pposToTarget?.bearingMagnetic,
              crossTrackDistance: math.crossTrackDistance
            )
            .accessibilityIdentifier("cdi")
          }
        case .countdownOnly:
          if let timeOnTarget = target.timeOnTarget {
            CountdownView(timeOnTarget: timeOnTarget)
              .accessibilityIdentifier("countdown")
          }
        case .postPass:
          EmptyView()
      }

      if event.isSimulating { SimulatorBanner() }

      switch guidance {
        case .toIPWithSpeedGuidance:
          if let fromTo = math.pposToIP, let desiredTimeOverIP = target.desiredTimeOverIP {
            TimingView(timeOnTarget: desiredTimeOverIP, fromTo: fromTo, onTimeDeltaTOT: 30)
          }
        case .toIPWithCountdown:
          if let fromTo = math.pposToIP, let desiredTimeOverIP = target.desiredTimeOverIP {
            VStack(alignment: .center, spacing: 0) {
              Text(
                .currentDate,
                format: .timer(
                  countingDownIn:
                    .now..<desiredTimeOverIP.addingTimeInterval(
                      -Double(services.clock.offsetFromRealTimeSeconds)
                    ),
                  maxPrecision: .seconds(1)
                )
              )
              .font(.title)
              .contentTransition(.numericText())
              Text("to Push")
                .font(.caption)
                .textCase(.uppercase)
            }
            .padding(.bottom)
            TOTView(fromTo: fromTo, timeOnTarget: desiredTimeOverIP, isPush: true)
          }
        case .toTarget:
          if let fromTo = math.pposToTarget, let timeOnTarget = target.timeOnTarget {
            TimingView(timeOnTarget: timeOnTarget, fromTo: fromTo, onTimeDeltaTOT: 30)
          }
        case .toTargetBypassingIP:
          if let fromTo = math.pposToTarget, let timeOnTarget = target.timeOnTarget {
            TimingView(
              timeOnTarget: timeOnTarget,
              fromTo: fromTo,
              onTimeDeltaTOT: 30,
              showRequiredSpeed: false
            )
          }
        case .countdownOnly:
          if let fromTo = math.pposToTarget {
            TOTView(
              fromTo: fromTo,
              timeOnTarget: target.desiredTimeOverIP,
              showSpeed: false,
              isPush: true
            )
          }
        case .postPass:
          EmptyView()
      }
    }.padding()
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
