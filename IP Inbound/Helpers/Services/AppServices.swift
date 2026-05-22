import SwiftUI

/// Single dependency aggregate for the injectable clock and location provider.
/// Built once at `@main` via ``AppServices/make(processInfo:)``.
@MainActor
@Observable
final class AppServices {
  let clock: any ClockProviding
  let location: any LocationProviding

  init(clock: any ClockProviding, location: any LocationProviding) {
    self.clock = clock
    self.location = location
  }

  /// Always live unless UI testing. The gate is `ProcessInfo.isRunningUITests`
  /// (the `-UITests` arg / `XCTestConfigurationFilePath` env). Each axis falls
  /// back independently when its `UITEST_*` var is absent or unparseable.
  ///
  /// `async` is required to hop onto `@LocationActor` to fetch
  /// `LocationStreamer.shared` in a Swift 6 strict-concurrency context. The
  /// live streamer is fetched lazily — only on the live path, or on the
  /// UI-test fallback when no `UITEST_LOCATION`/`UITEST_LOCATION_PATH` is
  /// supplied — so UI tests with a scripted fix never construct
  /// `CLLocationManager` or trigger a location-permission prompt.
  static func make(processInfo: ProcessInfo = .processInfo) async -> AppServices {
    guard processInfo.isRunningUITests else {
      return AppServices(clock: SystemClock(), location: await Self.liveLocationStreamer())
    }
    let clock: any ClockProviding = UITestClock(processInfo: processInfo) ?? SystemClock()
    if let uiTestLocation = UITestLocationProvider(
      processInfo: processInfo,
      dateProvider: clock.dateProvider
    ) {
      return AppServices(clock: clock, location: uiTestLocation)
    }
    return AppServices(clock: clock, location: await Self.liveLocationStreamer())
  }

  @LocationActor
  private static func liveLocationStreamer() -> LocationStreamer {
    LocationStreamer.shared
  }
}

// MARK: - SwiftUI environment key

private struct AppServicesKey: EnvironmentKey {
  static let defaultValue: AppServices? = nil
}

/// Placeholder location provider for the pre-injection default. `@main` always
/// injects a real `AppServices`; this is only reached in previews that do not
/// inject their own services, and during the brief window before the first
/// `task` on the root view completes.
private struct FallbackLocationProvider: LocationProviding {
  // swiftlint:disable:next async_without_await
  func start() async {}
  // swiftlint:disable:next async_without_await
  func stop() async {}
  // swiftlint:disable:next async_without_await
  func eventStream() async -> AsyncThrowingStream<LocationEvent, any Error>? { nil }
  // swiftlint:disable:next async_without_await
  func currentEvent() async -> LocationEvent? { nil }
}

@MainActor private let defaultAppServices = AppServices(
  clock: SystemClock(),
  location: FallbackLocationProvider()
)

extension EnvironmentValues {
  /// `@MainActor` accessor with a lazily-built system default for previews and
  /// any view rendered before `@main` injects the real aggregate. Uses the
  /// optional-key + `@MainActor` getter pattern because an `EnvironmentKey`
  /// default cannot itself be `@MainActor`-isolated.
  @MainActor var services: AppServices {
    get { self[AppServicesKey.self] ?? defaultAppServices }
    set { self[AppServicesKey.self] = newValue }
  }
}
