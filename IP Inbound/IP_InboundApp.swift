import Bugsnag
import BugsnagPerformance
import CloudKit
import CoreData
import MetalKit
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
        Bugsnag.start()
        BugsnagPerformance.start()

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
        guard FileManager.default.ubiquityIdentityToken != nil else { return ModelConfiguration(for: Target.self) }

        let config = ModelConfiguration()

#if DEBUG
        // Use an autorelease pool to make sure Swift deallocates the persistent
        // container before setting up the SwiftData stack.
        try autoreleasepool {
            let desc = NSPersistentStoreDescription(url: config.url)
            let opts = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.codes.tim.IP-Inbound")
            desc.cloudKitContainerOptions = opts
            // Load the store synchronously so it completes before initializing the
            // CloudKit schema.
            desc.shouldAddStoreAsynchronously = false
            if let mom = NSManagedObjectModel.makeManagedObjectModel(for: [Target.self]) {
                let container = NSPersistentCloudKitContainer(name: "IP Inbound", managedObjectModel: mom)
                container.persistentStoreDescriptions = [desc]
                container.loadPersistentStores {_, err in
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
