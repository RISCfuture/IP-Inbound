import SwiftUI

private let minSpeed = Measurement(value: 30, unit: UnitSpeed.knots).converted(to: .metersPerSecond).value

struct FlyView: View {
    var target: Target

    @Environment(\.errorStore)
    var errorStore

    var body: some View {
        NeedsLocationView { location, event in
            let math = IPTargetMath(location: location, target: target),
                isMoving = location.speed > minSpeed

            let guidance: Guidance = if !isMoving { .countdownOnly }
            else if math.isPastIP { .toTarget }
            else if let IPDeltaTime = math.IPDeltaTime,
            let latestIPDeltaTime = math.latestIPDeltaTime {
                if IPDeltaTime < -60 { .toIPWithCountdown }
                else if IPDeltaTime > latestIPDeltaTime { .toTargetBypassingIP }
                else { .toIPWithSpeedGuidance }
            } else {
                .countdownOnly
            }

            VStack {
                VStack {
                    switch guidance {
                        case .toIPWithSpeedGuidance, .toIPWithCountdown:
                            Text("P.POS → IP").font(.title)
                            Text(target.name).font(.caption)
                        case .toTarget:
                            Text("P.POS → Target").font(.title)
                            Text(target.name).font(.caption)
                        case .toTargetBypassingIP:
                            Text("P.POS → Target").font(.title).foregroundStyle(Color.red)
                            Text(target.name).font(.caption)
                        case .countdownOnly:
                            Text(target.name).font(.title)
                    }
                }

                switch guidance {
                    case .toIPWithSpeedGuidance, .toIPWithCountdown:
                        if let fromTo = math.pposToIP {
                            CDIView(heading: fromTo.trackMagnetic,
                                    bearing: fromTo.bearingMagnetic,
                                    bearingColor: .yellow,
                                    IPDirectBearing: nil,
                                    targetDirectBearing: math.pposToTarget?.bearingMagnetic,
                                    crossTrackDistance: nil)
                            .accessibilityIdentifier("cdi")
                        }
                    case .toTarget, .toTargetBypassingIP:
                        if let fromTo = math.pposToTarget {
                            CDIView(heading: fromTo.trackMagnetic,
                                    bearing: target.desiredTrackMagnetic,
                                    bearingColor: .red,
                                    IPDirectBearing: math.pposToIP?.bearingMagnetic,
                                    targetDirectBearing: math.pposToTarget?.bearingMagnetic,
                                    crossTrackDistance: math.crossTrackDistance)
                            .accessibilityIdentifier("cdi")
                        }
                    case .countdownOnly:
                        if let timeOnTarget = target.timeOnTarget {
                            CountdownView(timeOnTarget: timeOnTarget)
                                .accessibilityIdentifier("countdown")
                        }
                }

                if event.isSimulating { SimulatorBanner() }

                switch guidance {
                    case .toIPWithSpeedGuidance:
                        if let fromTo = math.pposToIP, let timeOnTarget = target.timeOnTarget {
                            TimingView(timeOnTarget: timeOnTarget, fromTo: fromTo, onTimeDeltaTOT: 30)
                        }
                    case .toIPWithCountdown:
                        if let fromTo = math.pposToIP, let desiredTimeOverIP = target.desiredTimeOverIP {
                            Text(.currentDate, format: .timer(countingDownIn: .now..<desiredTimeOverIP, maxPrecision: .seconds(1)))
                                .font(.title)
                                .padding(.bottom)
                            TOTView(fromTo: fromTo, timeOnTarget: desiredTimeOverIP)
                        }
                    case .toTarget, .toTargetBypassingIP:
                        if let fromTo = math.pposToTarget, let timeOnTarget = target.timeOnTarget {
                            TimingView(timeOnTarget: timeOnTarget, fromTo: fromTo, onTimeDeltaTOT: 30)
                        }
                    case .countdownOnly:
                        if let fromTo = math.pposToTarget {
                            TOTView(fromTo: fromTo, timeOnTarget: target.desiredTimeOverIP, showSpeed: false)
                        }
                }
            }.padding()
        }.onAppear {
            target.isConfigured = true
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private enum Guidance {
        case toIPWithSpeedGuidance
        case toIPWithCountdown
        case toTarget
        case toTargetBypassingIP
        case countdownOnly
    }
}

#Preview("On Ground - Portrait") {
    let helper = PreviewHelper()
    FlyView(target: helper.target(minutesFromNow: 10))
        .environment(\.previewLocation, helper.groundEvent)
}

#Preview("On Ground - Landscape", traits: .landscapeLeft) {
    let helper = PreviewHelper()
    FlyView(target: helper.target(minutesFromNow: 10))
        .environment(\.previewLocation, helper.groundEvent)
}

#Preview("Pre-IP, Early - Portrait") {
    let helper = PreviewHelper()
    FlyView(target: helper.target(minutesFromNow: 10))
        .environment(\.previewLocation, helper.preIPEvent)
}

#Preview("Pre-IP, Early - Landscape", traits: .landscapeLeft) {
    let helper = PreviewHelper()
    FlyView(target: helper.target(minutesFromNow: 10))
        .environment(\.previewLocation, helper.preIPEvent)
}

#Preview("Pre-IP, On Time") {
    let helper = PreviewHelper()
    FlyView(target: helper.target(minutesFromNow: 2))
        .environment(\.previewLocation, helper.preIPEvent)
}

#Preview("Pre-IP, Late") {
    let helper = PreviewHelper()
    FlyView(target: helper.target(minutesFromNow: 1.5))
        .environment(\.previewLocation, helper.preIPEvent)
}

#Preview("IP-to-Target") {
    let helper = PreviewHelper()
    FlyView(target: helper.target(minutesFromNow: 1))
        .environment(\.previewLocation, helper.postIPEvent)
}
