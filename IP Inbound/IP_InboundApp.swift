import CloudKit
import CoreData
import MetalKit
import Sentry
import SwiftData
import SwiftUI

@main
struct IP_InboundApp: App {
  // MARK: - Type Properties

  private static var isRunningTests: Bool {
    // Detect unit tests (XCTestCase is loaded in the app process)
    if NSClassFromString("XCTestCase") != nil {
      return true
    }
    // Detect UI tests (test runner sets this environment variable, or
    // the test harness passes -UITests as a launch argument)
    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
      || ProcessInfo.processInfo.arguments.contains("-UITests")
    {
      return true
    }
    return false
  }

  // MARK: - Instance Properties

  private let modelContainer: ModelContainer

  @State private var services: AppServices?

  var body: some Scene {
    WindowGroup {
      Group {
        if let services {
          ContentView()
            .environment(\.services, services)
        } else {
          Color(.systemBackground)
            .ignoresSafeArea()
        }
      }
      .environment(\.errorStore, ErrorStore())
      .environment(\.previewLocation, nil)
      .task {
        if services == nil {
          services = await AppServices.make()
        }
      }
    }.modelContainer(modelContainer)
  }

  // MARK: - Initializers

  init() {
    Self.startSentryUnlessRunningUITests()

    // Ensure Metal is available
    _ = MTLCreateSystemDefaultDevice()

    do {
      let config = try Self.createCloudKitStore()
      modelContainer = try ModelContainer(for: Target.self, configurations: config)
    } catch {
      fatalError(error.localizedDescription)
    }
    Self.seedUITestTargetIfNeeded(into: modelContainer)
  }

  // MARK: - Type Methods

  /// Sentry stays off under UI tests: its logging, profiling, and structured logging do
  /// main-thread work that keeps the run loop from going idle, which stalls XCUITest's
  /// wait-for-idle and times tests out (matches FART).
  private static func startSentryUnlessRunningUITests() {
    guard !ProcessInfo.processInfo.isRunningUITests else { return }

    SentrySDK.start { options in
      options.dsn =
        "https://6d826473ed575a590d160fa29163b480@o4510156629475328.ingest.us.sentry.io/4510161641996288"

      // The SDK's own logging is for whoever is working on the app, not for a device in the field.
      #if DEBUG
        options.debug = true
      #endif

      // There are no accounts here, and the privacy manifest declares diagnostics as not linked to
      // identity — so never attach the user's IP address or other identifying context to an event.
      options.sendDefaultPii = false

      // A fifth of the traffic is enough to spot a performance regression in an app this size, and
      // it leaves the quota and the device's battery for the crashes that actually matter.
      options.tracesSampleRate = 0.2

      options.configureProfiling = {
        $0.sessionSampleRate = 0.2
        $0.lifecycle = .trace
      }

      options.enableLogs = true

      // Hangs are inferred from stalled frame rendering, and this app sits on a static screen for
      // long stretches in flight — where nothing rendering means nothing is moving, not that the
      // main thread is stuck. The two-second default reports those as hangs.
      options.appHangTimeoutInterval = 5

      // Discard events from simulator and debug builds: the former is noise, the latter reports
      // debugger-induced app hangs (a paused main thread trips the watchdog) that don't reflect
      // production behavior.
      options.beforeSend = { event in
        #if DEBUG || targetEnvironment(simulator)
          return nil
        #else
          return event
        #endif
      }
    }
  }

  private static func seedUITestTargetIfNeeded(into modelContainer: ModelContainer) {
    let info = ProcessInfo.processInfo
    guard info.isRunningUITests else { return }
    let context = modelContainer.mainContext

    if info.environment["UITEST_SEED_TARGET"] == "1" {
      let name = info.environment["UITEST_SEED_TARGET_NAME"] ?? "Flythrough"
      context.insert(makeSeedTarget(name: name, totISO: "2026-05-18T18:00:00.000Z"))
    }

    // Secondary seed for the post-pass flow: a second pre-configured target so
    // PostPassView's "Fly next target" has a candidate. Inserts when both
    // UITEST_SEED_TARGET=1 and UITEST_SEED_NEXT_TARGET=1 are set.
    if info.environment["UITEST_SEED_NEXT_TARGET"] == "1" {
      let name = info.environment["UITEST_SEED_NEXT_TARGET_NAME"] ?? "NextHop"
      context.insert(
        makeSeedTarget(
          name: name,
          totISO: "2026-05-18T18:15:00.000Z",
          coordinate: Coordinate(latitude: 36.500000, longitude: -115.500000)
        )
      )
    }

    try? context.save()
  }

  private static func makeSeedTarget(
    name: String,
    totISO: String,
    coordinate: Coordinate = Coordinate(latitude: 36.772367, longitude: -115.453840)
  ) -> Target {
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let plainFormatter = ISO8601DateFormatter()
    let tot = isoFormatter.date(from: totISO) ?? plainFormatter.date(from: totISO)
    let target = Target(name: name, coordinate: coordinate)
    target.offsetBearing = 359
    target.offsetBearingIsTrue = true
    target.offsetDistance = 4.8
    target.targetGroundSpeed = 120
    target.timeOnTarget = tot
    target.isConfigured = true
    return target
  }

  private static func createCloudKitStore() throws -> ModelConfiguration {
    // Disable CloudKit entirely when running tests to avoid blocking the main
    // thread waiting for CloudKit operations that will fail in the simulator.
    if isRunningTests {
      return ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    }

    guard FileManager.default.ubiquityIdentityToken != nil else {
      return ModelConfiguration(for: Target.self)
    }

    let config = ModelConfiguration()

    #if DEBUG

      // Use an autorelease pool to make sure Swift deallocates the persistent
      // container before setting up the SwiftData stack.
      try autoreleasepool {
        let desc = NSPersistentStoreDescription(url: config.url)
        let opts = NSPersistentCloudKitContainerOptions(
          containerIdentifier: "iCloud.codes.tim.IP-Inbound"
        )
        desc.cloudKitContainerOptions = opts
        // Load the store synchronously so it completes before initializing the
        // CloudKit schema.
        desc.shouldAddStoreAsynchronously = false
        if let mom = NSManagedObjectModel.makeManagedObjectModel(for: [Target.self]) {
          let container = NSPersistentCloudKitContainer(name: "IP Inbound", managedObjectModel: mom)
          container.persistentStoreDescriptions = [desc]
          container.loadPersistentStores { _, err in
            if let err {
              fatalError(err.localizedDescription)
            }
          }
          // Initialize the CloudKit schema after the store finishes loading.
          try container.initializeCloudKitSchema()
          // Remove and unload the store from the persistent container.
          if container.persistentStoreCoordinator.persistentStores.first != nil {
            //                    try container.persistentStoreCoordinator.remove(store)
          }
        }
      }
    #endif

    return config
  }
}
