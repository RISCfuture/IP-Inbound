import IP_Inbound_Shared
import SwiftUI

/// Stands in for run-in guidance when there is no fix to draw it from, saying which of the several
/// quite different reasons applies and offering the one action that resolves it.
struct NoLocationView: View {
  private static let stackSpacing: CGFloat = 20

  /// What is in the way, or `nil` when a fix simply has not arrived yet.
  var impediment: LocationImpediment?

  @Environment(\.openURL)
  private var openURL

  @Environment(\.services)
  private var services

  var body: some View {
    VStack(spacing: Self.stackSpacing) {
      Image(systemName: symbol)
        .imageScale(.large)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text(message)
        .font(.title)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      action
    }
    // Without this the container's identifier is applied to every descendant, replacing the one the
    // action button sets for itself.
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(identifier)
    .padding()
  }

  @ViewBuilder private var action: some View {
    switch impediment {
      case .accuracyLimited:
        Button("Enable Precise Location") { requestFullAccuracy() }
          .accessibilityIdentifier("enablePreciseLocationButton")
      case let impediment? where impediment.isResolvedInSettings:
        Button("Open Settings") { openSettings() }
          .accessibilityIdentifier("openSettingsButton")
      default:
        EmptyView()
    }
  }

  private var symbol: String {
    switch impediment {
      case .accuracyLimited: "location.magnifyingglass"
      case .unavailable, .none: "location.slash"
      default: "location.slash.circle"
    }
  }

  private var message: LocalizedStringKey {
    switch impediment {
      case .locationServicesOff: "Location Services is off."
      case .denied: "IP Inbound isn’t allowed to use your location."
      case .restricted: "Location access is restricted on this device."
      case .serviceSessionRequired, .insufficientlyInUse: "Location updates are paused."
      case .unavailable: "Your location can’t be determined."
      case .accuracyLimited: "Precise location is off."
      case .none: "No location."
    }
  }

  /// The no-fix identifier is the one the UI tests already key off, so it stays put; the rest are new.
  private var identifier: String {
    switch impediment {
      case .locationServicesOff: "locationServicesOffView"
      case .denied: "locationDeniedView"
      case .restricted: "locationRestrictedView"
      case .serviceSessionRequired, .insufficientlyInUse: "locationPausedView"
      case .unavailable: "locationUnavailableView"
      case .accuracyLimited: "locationAccuracyLimitedView"
      case .none: "noLocationView"
    }
  }

  private func openSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    openURL(url)
  }

  private func requestFullAccuracy() {
    let provider = services.location
    Task { await provider.requestFullAccuracy() }
  }
}

#Preview("No fix") {
  NoLocationView(impediment: nil)
}

#Preview("Denied") {
  NoLocationView(impediment: .denied)
}

#Preview("Reduced accuracy") {
  NoLocationView(impediment: .accuracyLimited)
}
