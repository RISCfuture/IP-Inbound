import CloudKit
import CoreData
import MetalKit
import Sentry
import SwiftData
import SwiftUI

@main
struct IP_InboundApp: App {
  private let modelContainer: ModelContainer

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.errorStore, ErrorStore())
        .environment(\.previewLocation, nil)
    }.modelContainer(modelContainer)
  }

  init() {
    SentrySDK.start { options in
      options.dsn =
        "https://6d826473ed575a590d160fa29163b480@o4510156629475328.ingest.us.sentry.io/4510161641996288"
      options.debug = true  // Enabled debug when first installing is always helpful

      // Adds IP for users.
      // For more information, visit: https://docs.sentry.io/platforms/apple/data-management/data-collected/
      options.sendDefaultPii = true

      // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0

      // Configure profiling. Visit https://docs.sentry.io/platforms/apple/profiling/ to learn more.
      options.configureProfiling = {
        $0.sessionSampleRate = 1.0  // We recommend adjusting this value in production.
        $0.lifecycle = .trace
      }

      // Uncomment the following lines to add more data to your events
      // options.attachScreenshot = true // This adds a screenshot to the error events
      // options.attachViewHierarchy = true // This adds the view hierarchy to the error events

      // Enable experimental logging features
      options.experimental.enableLogs = true

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

  private static func createCloudKitStore() throws -> ModelConfiguration {
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
          if let store = container.persistentStoreCoordinator.persistentStores.first {
            //                    try container.persistentStoreCoordinator.remove(store)
          }
        }
      }
    #endif

    return config
  }
}
