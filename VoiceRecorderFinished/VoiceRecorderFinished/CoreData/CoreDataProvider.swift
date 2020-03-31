import CoreData

protocol CoreDataProvider {
  var mainContext: NSManagedObjectContext { get }
  var backgroundContext: NSManagedObjectContext { get }
  func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void)
  func performForegroundTask(_ block: @escaping (NSManagedObjectContext) -> Void)
}
