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
}
