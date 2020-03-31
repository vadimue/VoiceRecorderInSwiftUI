import CoreData
import Foundation

extension RecordingMO: ManagedObjectProtocol {
  func toEntity() -> Recording? {
    guard let url = URL(string: fileURL ?? ""),
        let createdAt = createdAt else { return nil }
    return Recording(fileURL: url, createdAt: createdAt)
  }
}
