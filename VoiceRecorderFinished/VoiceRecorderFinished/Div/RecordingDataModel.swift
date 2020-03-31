//RecordingDataModel.swift

//Created by BLCKBIRDS on 28.10.19.
//Visit www.BLCKBIRDS.com for more.

import CoreData

struct Recording {
    let fileURL: URL
    let createdAt: Date
}

extension Recording: ManagedObjectConvertible {
    func toManagedObject(in context: NSManagedObjectContext) -> RecordingMO? {
        let recordingMO = RecordingMO.getOrCreateSingle(with: fileURL.absoluteString, from: context)
        recordingMO.identifier = fileURL.absoluteString
        recordingMO.fileURL = fileURL.absoluteString
        recordingMO.createdAt = createdAt
        return recordingMO
    }
}
