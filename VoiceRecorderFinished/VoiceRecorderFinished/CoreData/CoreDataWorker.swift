import CoreData

enum CoreDataWorkerError: Error {
  case cannotFetch(String)
  case cannotSave(Error)
}

typealias CompletionBlock = (() -> Void)

protocol CoreDataWorkerProtocol {
  func get<Entity: ManagedObjectConvertible>
  (with predicate: NSPredicate?,
   sortDescriptors: [NSSortDescriptor]?,
   fetchLimit: Int?,
   completion: @escaping (Result<[Entity], Error>) -> Void)
  func upsert<Entity: ManagedObjectConvertible>
  (entities: [Entity],
   completion: @escaping (Error?) -> Void)
  func subscribeToStorageUpdate(_ notifyingHandler: @escaping CompletionBlock)
  func unsubscribeFromStorageUpdate()
}

extension CoreDataWorkerProtocol {
  func get<Entity: ManagedObjectConvertible>
  (with predicate: NSPredicate? = nil,
   sortDescriptors: [NSSortDescriptor]? = nil,
   fetchLimit: Int? = nil,
   completion: @escaping (Result<[Entity], Error>) -> Void) {
    get(with: predicate,
        sortDescriptors: sortDescriptors,
        fetchLimit: fetchLimit,
        completion: completion)
  }
}

class CoreDataWorker: CoreDataWorkerProtocol {
  private let coreDataProvider: CoreDataProvider

  private var notifyingHandler: CompletionBlock?

  init(coreDataProvider: CoreDataProvider) {
    self.coreDataProvider = coreDataProvider
  }

  func get<Entity: ManagedObjectConvertible>
  (with predicate: NSPredicate?,
   sortDescriptors: [NSSortDescriptor]?,
   fetchLimit: Int?,
   completion: @escaping (Result<[Entity], Error>) -> Void) {
    coreDataProvider.performForegroundTask { context in
      do {
        let fetchRequest = Entity.ManagedObject.fetchRequest()
        fetchRequest.predicate = predicate
        fetchRequest.sortDescriptors = sortDescriptors
        if let fetchLimit = fetchLimit {
          fetchRequest.fetchLimit = fetchLimit
        }
        let results = try context.fetch(fetchRequest) as? [Entity.ManagedObject]
        let items: [Entity] = results?.compactMap { $0.toEntity() as? Entity } ?? []
        completion(.success(items))
      } catch {
        let fetchError = CoreDataWorkerError.cannotFetch("Cannot fetch error: \(error))")
        completion(.failure(fetchError))
      }
    }
  }

  func upsert<Entity: ManagedObjectConvertible>
  (entities: [Entity],
   completion: @escaping (Error?) -> Void) {
    coreDataProvider.performBackgroundTask { context in
      _ = entities.compactMap { (entity) -> Entity.ManagedObject? in
        entity.toManagedObject(in: context)
      }
      do {
        try context.save()
        completion(nil)
      } catch {
        completion(CoreDataWorkerError.cannotSave(error))
      }
    }
  }

  func subscribeToStorageUpdate(_ notifyingHandler: @escaping CompletionBlock) {
    self.notifyingHandler = notifyingHandler
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(contextDidSave(from:)),
                                           name: .NSManagedObjectContextDidSave,
                                           object: coreDataProvider.backgroundContext)
  }

  func unsubscribeFromStorageUpdate() {
    NotificationCenter.default.removeObserver(self,
                                              name: .NSManagedObjectContextDidSave,
                                              object: coreDataProvider.backgroundContext)
  }

  @objc
  private func contextDidSave(from _: Notification) {
    notifyingHandler?()
  }
}
