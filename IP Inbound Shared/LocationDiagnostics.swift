public import CoreLocation

/// Why Core Location is not delivering a usable fix, as reported alongside each `CLLocationUpdate`.
///
/// Every one of these renders as the same "No location" screen without it, which tells the pilot
/// nothing about whether the fix is coming, whether they can do something about it, or whether the
/// guidance they *are* seeing is trustworthy.
public struct LocationDiagnostics: Sendable, Equatable {
  /// Nothing is wrong. The state of a feed that Core Location does not gate — a flight simulator's,
  /// or a scripted one under UI tests.
  public static let clean = Self()

  public var accuracyLimited = false
  public var authorizationDenied = false
  public var authorizationDeniedGlobally = false
  public var authorizationRequestInProgress = false
  public var authorizationRestricted = false
  public var insufficientlyInUse = false
  public var locationUnavailable = false
  public var serviceSessionRequired = false

  /// The one state worth showing the pilot, or `nil` when guidance should be drawn as usual.
  ///
  /// Ordered by what the pilot can do about it: an authorization problem outranks a missing fix,
  /// because the fix is missing *because* of it. `accuracyLimited` comes last because it is the only
  /// case that arrives with a location attached, so it is the only one that suppresses guidance that
  /// would otherwise draw.
  public var impediment: LocationImpediment? {
    // The prompt is on screen and the pilot has not answered it. Reporting a denial they have not
    // made would be wrong, and would flash on every first launch.
    if authorizationRequestInProgress { return nil }
    if authorizationDeniedGlobally { return .locationServicesOff }
    if authorizationDenied { return .denied }
    if authorizationRestricted { return .restricted }
    if serviceSessionRequired { return .serviceSessionRequired }
    if insufficientlyInUse { return .insufficientlyInUse }
    if locationUnavailable { return .unavailable }
    if accuracyLimited { return .accuracyLimited }
    return nil
  }

  public init() {}

  public init(_ update: CLLocationUpdate) {
    accuracyLimited = update.accuracyLimited
    authorizationDenied = update.authorizationDenied
    authorizationDeniedGlobally = update.authorizationDeniedGlobally
    authorizationRequestInProgress = update.authorizationRequestInProgress
    authorizationRestricted = update.authorizationRestricted
    insufficientlyInUse = update.insufficientlyInUse
    locationUnavailable = update.locationUnavailable
    serviceSessionRequired = update.serviceSessionRequired
  }
}

/// What stands between the pilot and run-in guidance, and therefore what to say about it.
public enum LocationImpediment: Sendable, Equatable {
  /// Location Services is off for the whole device.
  case locationServicesOff

  /// The pilot denied this app location access.
  case denied

  /// Authorization is withheld and cannot be changed here — parental restrictions, or an MDM profile.
  case restricted

  /// The app holds authorization but no service session, so updates are withheld.
  case serviceSessionRequired

  /// The app is not sufficiently in use to receive updates.
  case insufficientlyInUse

  /// The device cannot determine where it is. Nothing to be done but wait.
  case unavailable

  /// Fixes are arriving, but reduced to a precision the run-in geometry cannot be flown from.
  case accuracyLimited

  /// Whether the pilot's answer to the authorization prompt is what stands in the way.
  ///
  /// These are the refusals that end the update stream outright, so they are also the only ones
  /// worth restarting it for: the pilot has been somewhere else to lift one, and Core Location does
  /// not re-offer a stream it ended.
  public var deniesAuthorization: Bool {
    switch self {
      case .locationServicesOff, .denied, .restricted: true
      case .serviceSessionRequired, .insufficientlyInUse, .unavailable, .accuracyLimited: false
    }
  }

  /// Whether the Settings app is where the pilot fixes this.
  public var isResolvedInSettings: Bool {
    switch self {
      case .locationServicesOff, .denied, .restricted: true
      case .serviceSessionRequired, .insufficientlyInUse, .unavailable, .accuracyLimited: false
    }
  }
}
