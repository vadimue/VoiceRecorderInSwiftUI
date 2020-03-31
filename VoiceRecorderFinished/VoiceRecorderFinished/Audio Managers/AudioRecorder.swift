//AudioRecorder.swift

//Created by BLCKBIRDS on 28.10.19.
//Visit www.BLCKBIRDS.com for more.

import Foundation
import SwiftUI
import AVFoundation
import Combine

class AudioRecorder: NSObject,ObservableObject {
    
    private let coreDataWorker: CoreDataWorkerProtocol
    
    init(coreDataWorker: CoreDataWorkerProtocol) {
        self.coreDataWorker = coreDataWorker
        super.init()
        fetchRecordings()
    }
    
    let objectWillChange = PassthroughSubject<AudioRecorder, Never>()
    
    var audioRecorder: AVAudioRecorder!
    
    var recordings = [Recording]()
    
    var recording = false {
        didSet {
            objectWillChange.send(self)
        }
    }
    
    func startRecording() {
        let recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
        } catch {
            print("Failed to set up recording session")
        }
        
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentPath.appendingPathComponent("\(Date().toString(dateFormat: "dd-MM-YY_'at'_HH:mm:ss")).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder.record()
            
            recording = true
        } catch {
            print("Could not start recording")
        }
    }
    
    func stopRecording() {
        audioRecorder.stop()
        recording = false
        coreDataWorker.upsert(entities: [Recording(fileURL: audioRecorder.url, createdAt: Date())]) { _ in
            self.fetchRecordings()
        }
    }
    
    func fetchRecordings() {
        recordings.removeAll()
        let sortDescriptor = NSSortDescriptor(keyPath: \RecordingMO.createdAt, ascending: true)
        coreDataWorker.get(with: nil,
                           sortDescriptors: [sortDescriptor],
                           fetchLimit: nil) { [weak self] (result: Result<[Recording], Error>) in
                            guard let self = self else { return }
                            switch result {
                                case let .success(records):
                                    self.recordings = records
                                case .failure:
                                    return
                            }
                            self.objectWillChange.send(self)
        }
    }
    
    func deleteRecording(urlsToDelete: [URL]) {
        
        for url in urlsToDelete {
            print(url)
            do {
               try FileManager.default.removeItem(at: url)
            } catch {
                print("File could not be deleted!")
            }
        }
        
        fetchRecordings()
    }
    
}
