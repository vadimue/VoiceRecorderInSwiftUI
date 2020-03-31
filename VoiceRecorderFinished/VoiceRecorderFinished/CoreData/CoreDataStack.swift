import CoreData

enum CoreDataError: Error {
  case initializationError
}

enum StackType {
  case inMemory
  case sqlite

  func toString() -> String {
    switch self {
    case .inMemory:
      return NSInMemoryStoreType
    case .sqlite:
      return NSSQLiteStoreType
    }
  }
}

class CoreDataStack: CoreDataProvider {
  private var managedObjectModel: NSManagedObjectModel!
  private var coordinator: NSPersistentStoreCoordinator!

  private(set) lazy var mainContext: NSManagedObjectContext = { [unowned self] in
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    context.persistentStoreCoordinator = self.coordinator
    context.observeSave(from: self.backgroundContext)
    return context
  }()

  private(set) lazy var backgroundContext: NSManagedObjectContext = { [unowned self] in
    let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
    context.persistentStoreCoordinator = self.coordinator
    return context
  }()

  init(modelURL: URL, databaseURL: URL, stackType: StackType = .sqlite) throws {
    managedObjectModel = try createModel(modelURL: modelURL)
    coordinator = try createCoordinator(databaseURL: databaseURL, type: stackType)
  }

  private func createModel(modelURL: URL) throws -> NSManagedObjectModel {
    guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
      print("NSManagedObjectModel nil")
      throw CoreDataError.initializationError
    }
    return managedObjectModel
  }

  private func createCoordinator(databaseURL: URL, type: StackType) throws -> NSPersistentStoreCoordinator {
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
    try coordinator.addPersistentStore(ofType: type.toString(),
                                       configurationName: nil,
                                       at: databaseURL,
                                       options: [NSMigratePersistentStoresAutomaticallyOption: true,
                                                 NSInferMappingModelAutomaticallyOption: true])
    return coordinator
  }

  func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
    backgroundContext.perform {
      block(self.backgroundContext)
    }
  }

  func performForegroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
    mainContext.perform {
      block(self.mainContext)
    }
  }
}

extension NSManagedObjectContext {
  func observeSave(from context: NSManagedObjectContext) {
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(didSave(from:)),
                                           name: .NSManagedObjectContextDidSave,
                                           object: context)
  }

  @objc
  private func didSave(from notification: Notification) {
    mergeChanges(fromContextDidSave: notification)
  }
}
