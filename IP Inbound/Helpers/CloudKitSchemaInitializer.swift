#if DEBUG
  import CoreData
  import Foundation
  import SwiftData

  /// Writes every record type and field of the app's models to the CloudKit container's
  /// Development schema, for deploying to Production from CloudKit Console.
  ///
  /// CloudKit adds a field to Development only when a record carrying a value for it arrives, so
  /// a schema left to ordinary use misses whatever the developer never happened to save.
  /// `initializeCloudKitSchema()` uploads a sample record of every type with every field, then
  /// deletes it. SwiftData has no equivalent, so this stands up an `NSPersistentCloudKitContainer`
  /// over the same models in a throwaway store, initializes the schema through it, and quits.
  ///
  /// It quits rather than letting the launch carry on because the app's own store must not open
  /// in the same run: its mirror would sync the same zone the sample records are written to and
  /// cleared from.
  ///
  /// Debug builds only, and only when launched with ``launchArgument``: it is a slow network
  /// operation, and a Debug build is the one that talks to the Development environment.
  enum CloudKitSchemaInitializer {
    /// The launch argument that asks for the schema to be written.
    static let launchArgument = "-initializeCloudKitSchema"

    /// Writes `models` to the Development environment of `containerIdentifier` and exits, if
    /// this launch asked for it; does nothing otherwise.
    static func initializeIfRequested(
      models: [any PersistentModel.Type],
      containerIdentifier: String
    ) {
      guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
      do {
        try initialize(models: models, containerIdentifier: containerIdentifier)
      } catch {
        fatalError("Could not initialize the CloudKit schema: \(error)")
      }
      print("Wrote the CloudKit schema to the Development environment.")
      exit(0)
    }

    private static func initialize(
      models: [any PersistentModel.Type],
      containerIdentifier: String
    ) throws {
      guard let model = NSManagedObjectModel.makeManagedObjectModel(for: models) else {
        fatalError("SwiftData could not express the schema as a Core Data model.")
      }
      let storeURL = URL.temporaryDirectory.appending(path: "CloudKitSchema-\(UUID()).sqlite")
      let container = NSPersistentCloudKitContainer(
        name: "CloudKitSchema",
        managedObjectModel: model
      )
      container.persistentStoreDescriptions = [
        storeDescription(url: storeURL, containerIdentifier: containerIdentifier)
      ]

      var loadError: (any Error)?
      container.loadPersistentStores { _, error in loadError = error }
      if let loadError { throw loadError }

      try container.initializeCloudKitSchema()
      for store in container.persistentStoreCoordinator.persistentStores {
        try container.persistentStoreCoordinator.remove(store)
      }
      try? FileManager.default.removeItem(at: storeURL)
    }

    private static func storeDescription(
      url: URL,
      containerIdentifier: String
    ) -> NSPersistentStoreDescription {
      let description = NSPersistentStoreDescription(url: url)
      description.shouldAddStoreAsynchronously = false
      description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
        containerIdentifier: containerIdentifier
      )
      return description
    }
  }
#endif
