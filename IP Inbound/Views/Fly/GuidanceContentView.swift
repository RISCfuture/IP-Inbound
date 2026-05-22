import SwiftUI

/// The active run-in guidance for a target: a phase header, the navigation display (CDI or
/// countdown), an optional simulator banner, and the timing/TOT readout. Composed of per-phase
/// subviews driven by the current ``Guidance``.
struct GuidanceContentView: View {
  var math: IPTargetMath
  var target: Target
  var guidance: Guidance
  var event: LocationEvent

  var body: some View {
    VStack {
      GuidanceHeader(target: target, guidance: guidance)
      GuidanceNavigationDisplay(math: math, target: target, guidance: guidance)
      if event.isSimulating { SimulatorBanner(simName: event.simName) }
      GuidanceTimingDisplay(math: math, target: target, guidance: guidance)
    }
    .padding()
  }
}

private struct GuidanceHeader: View {
  var target: Target
  var guidance: Guidance

  var body: some View {
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
  }
}

private struct GuidanceNavigationDisplay: View {
  var math: IPTargetMath
  var target: Target
  var guidance: Guidance

  var body: some View {
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
  }
}

private struct GuidanceTimingDisplay: View {
  private static let runInOnTimeDeltaTOT: TimeInterval = 30

  var math: IPTargetMath
  var target: Target
  var guidance: Guidance

  var body: some View {
    switch guidance {
      case .toIPWithSpeedGuidance:
        if let fromTo = math.pposToIP, let desiredTimeOverIP = target.desiredTimeOverIP {
          TimingView(
            timeOnTarget: desiredTimeOverIP,
            fromTo: fromTo,
            onTimeDeltaTOT: Self.runInOnTimeDeltaTOT
          )
        }
      case .toIPWithCountdown:
        if let fromTo = math.pposToIP, let desiredTimeOverIP = target.desiredTimeOverIP {
          CountdownTimerView(targetDate: desiredTimeOverIP, caption: "to Push")
            .padding(.bottom)
          TOTView(fromTo: fromTo, timeOnTarget: desiredTimeOverIP, isPush: true)
        }
      case .toTarget:
        if let fromTo = math.pposToTarget, let timeOnTarget = target.timeOnTarget {
          TimingView(
            timeOnTarget: timeOnTarget,
            fromTo: fromTo,
            onTimeDeltaTOT: Self.runInOnTimeDeltaTOT
          )
        }
      case .toTargetBypassingIP:
        if let fromTo = math.pposToTarget, let timeOnTarget = target.timeOnTarget {
          TimingView(
            timeOnTarget: timeOnTarget,
            fromTo: fromTo,
            onTimeDeltaTOT: Self.runInOnTimeDeltaTOT,
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
  }
}

#Preview("Pre-IP, On Time") {
  let helper = PreviewHelper()
  let target = helper.target(minutesFromNow: 4)
  let math = IPTargetMath(location: helper.preIPLocation, target: target, now: .now)
  GuidanceContentView(
    math: math,
    target: target,
    guidance: .toIPWithSpeedGuidance,
    event: helper.preIPEvent
  )
}

#Preview("IP → Target") {
  let helper = PreviewHelper()
  let target = helper.target(minutesFromNow: 1)
  let math = IPTargetMath(location: helper.postIPLocation, target: target, now: .now)
  GuidanceContentView(
    math: math,
    target: target,
    guidance: .toTarget,
    event: helper.postIPEvent
  )
}
