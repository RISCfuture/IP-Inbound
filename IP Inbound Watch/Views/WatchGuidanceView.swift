import CoreLocation
import IP_Inbound_Shared
import SwiftUI

/// Drives run-in guidance for the flown target from the watch's own GPS, drawing whichever screen
/// the phase of the run calls for. Gates on location availability.
struct WatchGuidanceView: View {
  var target: TargetSnapshot

  @Environment(WatchLocationModel.self)
  private var locationModel

  var body: some View {
    // Tested before the fix, because `accuracyLimited` arrives with one and the CDI must not be
    // drawn from a deliberately coarsened position.
    if let impediment = locationModel.diagnostics.impediment {
      WatchLocationUnavailableView(impediment: impediment)
    } else if let location = locationModel.location {
      WatchLocatedGuidance(location: location, target: target)
    } else {
      WatchAcquiringFixView()
    }
  }
}

private struct WatchAcquiringFixView: View {
  @ScaledMetric(relativeTo: .footnote)
  private var helpFontSize = 14.0

  var body: some View {
    VStack {
      ProgressView()
      Text("Acquiring GPS…")
        .font(.system(size: helpFontSize))
        .foregroundStyle(.secondary)
    }
  }
}

private struct WatchLocationUnavailableView: View {
  var impediment: LocationImpediment

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: "location.slash")
    } description: {
      Text(explanation)
    }
    .accessibilityIdentifier(identifier)
  }

  private var title: LocalizedStringKey {
    switch impediment {
      case .locationServicesOff: "Location Services Off"
      case .denied, .restricted: "Location Off"
      case .accuracyLimited: "Precise Location Off"
      case .unavailable: "No GPS"
      case .serviceSessionRequired, .insufficientlyInUse: "Location Paused"
    }
  }

  /// Every remedy is on the iPhone: the watch app has no Settings deep link, and the temporary
  /// full-accuracy prompt is not documented for watchOS.
  private var explanation: LocalizedStringKey {
    switch impediment {
      case .locationServicesOff: "Turn on Location Services in Settings to see guidance."
      case .denied, .restricted: "Allow location access for IP Inbound in Settings to see guidance."
      case .accuracyLimited: "Turn on Precise Location for IP Inbound to see guidance."
      case .unavailable: "Waiting for a GPS fix."
      case .serviceSessionRequired, .insufficientlyInUse: "Raise your wrist to resume guidance."
    }
  }

  private var identifier: String {
    switch impediment {
      case .locationServicesOff, .denied, .restricted: "watchLocationOff"
      case .accuracyLimited: "watchAccuracyLimited"
      case .unavailable: "watchNoGPS"
      case .serviceSessionRequired, .insufficientlyInUse: "watchLocationPaused"
    }
  }
}

/// Chooses between the airborne indicator and the countdown for a fix from the phase of the run it
/// puts the aircraft in, and hands the indicator the run-in geometry and the deviation that phase
/// calls for. The countdown stands wherever there is no run-in left to steer: on the ground, once the
/// pass is flown, and for a fix carrying no usable ground speed or course, which has no geometry to
/// solve at all.
private struct WatchLocatedGuidance: View {
  var location: CLLocation
  var target: TargetSnapshot

  /// The phase the last fix with geometry to solve put the aircraft in. A fix carrying no usable
  /// ground speed or course leaves it standing: it says nothing about where the run has got to, and
  /// letting it read as the on-ground countdown would drop a hold-off already under way.
  @State private var previousGuidance: Guidance?

  var body: some View {
    let math = IPTargetMath(location: location, target: target, now: Date())
    let helper = math.map {
      GuidanceHelper(
        math: $0,
        location: location,
        target: target,
        previousGuidance: previousGuidance
      )
    }
    let solvedGuidance = helper?.guidance
    let guidance = solvedGuidance ?? .countdownOnly

    Group {
      if let math, steersRunIn(guidance) {
        WatchCDIView(math: math, deviation: helper?.courseDeviation)
      } else {
        WatchCountdownView(target: target, guidance: guidance)
      }
    }
    // Only a fix that solved has a phase to carry forward: the countdown a bare fix falls back to
    // is what the screen shows, not a reading of the run.
    .onChange(of: solvedGuidance, initial: true) {
      if let solvedGuidance { previousGuidance = solvedGuidance }
    }
  }

  /// Whether `guidance` has a run-in to steer, and so something for the indicator to draw.
  private func steersRunIn(_ guidance: Guidance) -> Bool {
    switch guidance {
      case .toIPWithSpeedGuidance, .toIPWithCountdown, .toTarget, .toTargetBypassingIP: true
      case .countdownOnly, .postPass: false
    }
  }
}

#Preview("On Ground") {
  WatchGuidanceView(target: WatchPreviewData.target)
    .environment(WatchLocationModel(previewLocation: WatchPreviewData.location(speedKnots: 0)))
}

#Preview("Airborne") {
  WatchGuidanceView(target: WatchPreviewData.target)
    .environment(WatchLocationModel(previewLocation: WatchPreviewData.location(speedKnots: 250)))
}

#Preview("Acquiring a fix") {
  WatchGuidanceView(target: WatchPreviewData.target)
    .environment(WatchLocationModel())
}
