import Foundation

extension ProcessInfo {
  /// MapKit and CoreLocation live updates keep the app from signalling idle to
  /// XCTest on slower simulators (notably x86_64 Xcode Cloud runners), causing
  /// per-tap 60-second `waitForQuiescenceIncludingAnimationsIdle` stalls. Views
  /// and services that rely on those APIs consult this flag and substitute a
  /// quiescent equivalent when set.
  var isRunningUITests: Bool {
    environment["XCTestConfigurationFilePath"] != nil
      || arguments.contains("-UITests")
  }

  /// Whether the process is a SwiftUI preview or any kind of test run. Controllers that reach outside
  /// the app — a Live Activity, a WatchConnectivity session, a background activity session — consult
  /// this so a preview or a screenshot run never raises system UI the pilot did not ask for.
  ///
  /// Wider than ``isRunningUITests``: previews set no launch argument, and a unit test hosted in the
  /// app process sets no `-UITests` either, but both must stay inert.
  var isRunningPreviewsOrTests: Bool {
    environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
      || isRunningUITests
      || NSClassFromString("XCTestCase") != nil
  }
}
