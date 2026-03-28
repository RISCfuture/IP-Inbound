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

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.errorStore, ErrorStore())
        .environment(\.previewLocation, nil)
    }.modelContainer(modelContainer)
  }

  // MARK: - Initializers

  init() {
    SentrySDK.start { options in
      options.dsn =
        "https://6d826473ed575a590d160fa29163b480@o4510156629475328.ingest.us.sentry.io/4510161641996288"
      options.debug = true

      options.tracesSampleRate = 0.2

      options.configureProfiling = {
        $0.sessionSampleRate = 0.2
        $0.lifecycle = .trace
      }

      // Uncomment the following lines to add more data to your events
      // options.attachScreenshot = true // This adds a screenshot to the error events
      // options.attachViewHierarchy = true // This adds the view hierarchy to the error events

      // Enable structured logging
      options.enableLogs = true

      // Discard all events when running on simulator
      options.beforeSend = { event in
        #if targetEnvironment(simulator)
          return nil
        #else
          return event
        #endif
      }
    }

    // Ensure Metal is available
    _ = MTLCreateSystemDefaultDevice()

    do {
      let config = try Self.createCloudKitStore()
      modelContainer = try ModelContainer(for: Target.self, configurations: config)
    } catch {
      fatalError(error.localizedDescription)
    }
  }

  // MARK: - Type Methods

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
