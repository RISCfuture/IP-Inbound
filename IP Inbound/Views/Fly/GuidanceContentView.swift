import IP_Inbound_Shared
import MeasurementKitLocation
import SwiftUI

/// The active run-in guidance for a target: a phase header, the navigation display (CDI or
/// countdown), an optional simulator banner, and the timing/TOT readout. Composed of per-phase
/// subviews driven by the current ``Guidance``.
struct GuidanceContentView: View {
  /// The run-in geometry, or `nil` when the fix reports no usable ground speed or course. Only the
  /// phases that steer against a ground track read it; ``Guidance/countdownOnly`` is solved from
  /// `coordinate` and the target alone.
  var math: IPTargetMath<Target>?
  /// Where the aircraft is. Every fix carries a position, whether or not it carries motion.
  var coordinate: Coordinate
  var target: Target
  var guidance: Guidance
  /// Where the aircraft lies relative to the run-in course, already blanked in the phases that have
  /// no course line to deviate from.
  var courseDeviation: CourseDeviation?
  var event: LocationEvent

  var body: some View {
    VStack {
      GuidanceHeader(target: target, guidance: guidance)
      GuidanceNavigationDisplay(
        math: math,
        target: target,
        guidance: guidance,
        courseDeviation: courseDeviation
      )
      if event.isSimulating { SimulatorBanner(simName: event.simName) }
      GuidanceTimingDisplay(
        math: math,
        coordinate: coordinate,
        target: target,
        guidance: guidance
      )
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
  var math: IPTargetMath<Target>?
  var target: Target
  var guidance: Guidance
  var courseDeviation: CourseDeviation?

  var body: some View {
    switch guidance {
      case .toIPWithSpeedGuidance, .toIPWithCountdown:
        if let fromTo = math?.pposToIP {
          CDIView(
            track: fromTo.trackMagnetic,
            bearing: fromTo.bearingMagnetic,
            bearingColor: .yellow,
            IPDirectBearing: nil,
            targetDirectBearing: math?.pposToTarget?.bearingMagnetic,
            deviation: courseDeviation
          )
          .accessibilityIdentifier("cdi")
        }
      case .toTarget, .toTargetBypassingIP:
        if let math, let fromTo = math.pposToTarget {
          CDIView(
            track: fromTo.trackMagnetic,
            bearing: target.desiredTrackMagnetic,
            bearingColor: .red,
            IPDirectBearing: math.pposToIP?.bearingMagnetic,
            targetDirectBearing: fromTo.bearingMagnetic,
            deviation: courseDeviation
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
  var math: IPTargetMath<Target>?
  var coordinate: Coordinate
  var target: Target
  var guidance: Guidance

  var body: some View {
    switch guidance {
      case .toIPWithSpeedGuidance:
        if let fromTo = math?.pposToIP, let desiredTimeOverIP = target.desiredTimeOverIP {
          TimingView(
            timeOnTarget: desiredTimeOverIP,
            fromTo: fromTo,
            onTimeDeltaTOT: TimingTier.runInOnTimeDeltaTOT
          )
        }
      case .toIPWithCountdown:
        if let fromTo = math?.pposToIP, let desiredTimeOverIP = target.desiredTimeOverIP {
          CountdownTimerView(targetDate: desiredTimeOverIP, caption: "to Push")
            .padding(.bottom)
          TOTView(fromTo: fromTo, timeOnTarget: desiredTimeOverIP, isPush: true)
        }
      case .toTarget:
        if let fromTo = math?.pposToTarget, let timeOnTarget = target.timeOnTarget {
          TimingView(
            timeOnTarget: timeOnTarget,
            fromTo: fromTo,
            onTimeDeltaTOT: TimingTier.runInOnTimeDeltaTOT
          )
        }
      case .toTargetBypassingIP:
        if let fromTo = math?.pposToTarget, let timeOnTarget = target.timeOnTarget {
          TimingView(
            timeOnTarget: timeOnTarget,
            fromTo: fromTo,
            onTimeDeltaTOT: TimingTier.runInOnTimeDeltaTOT,
            showRequiredSpeed: false
          )
        }
      case .countdownOnly:
        // How far there is to fly and when to push are geometry between the aircraft's position and
        // the target: neither needs a ground speed or a course, so both stand while stopped.
        TOTView(
          distance: coordinate.distance(to: target.coordinate),
          timeOnTarget: target.desiredTimeOverIP,
          isPush: true
        )
      case .postPass:
        EmptyView()
    }
  }
}

#Preview("Pre-IP, On Time") {
  let helper = PreviewHelper()
  let target = helper.target(minutesFromNow: 4)
  let location = helper.preIPLocation
  GuidanceContentView(
    math: IPTargetMath(location: location, target: target, now: .now),
    coordinate: location.geoCoordinate,
    target: target,
    guidance: .toIPWithSpeedGuidance,
    courseDeviation: nil,
    event: helper.preIPEvent
  )
}

#Preview("IP → Target") {
  let helper = PreviewHelper()
  let target = helper.target(minutesFromNow: 1)
  let location = helper.postIPLocation
  let math = IPTargetMath(location: location, target: target, now: .now)
  GuidanceContentView(
    math: math,
    coordinate: location.geoCoordinate,
    target: target,
    guidance: .toTarget,
    courseDeviation: math?.courseDeviation,
    event: helper.postIPEvent
  )
}

#Preview("No Ground Speed") {
  let helper = PreviewHelper()
  let target = helper.target(minutesFromNow: 10)
  GuidanceContentView(
    math: nil,
    coordinate: helper.preIPLocation.geoCoordinate,
    target: target,
    guidance: .countdownOnly,
    courseDeviation: nil,
    event: helper.preIPEvent
  )
}
