//
//  MotionManager.swift
//  concurrent_test
//
//  Created by sezaki on 2023/06/07.
//

import SwiftUI
import Foundation
import CoreMotion
//import OpenAISwift

class MotionRecognitionService{
    private let manager = CMHeadphoneMotionManager()
    private let motion_classifier = MotionClassifier()
//    private let speaker_classifier = SpeakerClassifier()
    var motion_state = "motion_state"
    var speaker_state = "speaker_state"
    
    init(){
//        speaker_classifier = speechRecognitionService.classifier
    }
    
    func startMotionRecognition(speaker_classifier: SpeakerClassifier){
        manager.startDeviceMotionUpdates(to: OperationQueue()){ data, error in
            if error == nil {
//                print("motion")
                guard let new_data = data else {return}
                self.motion_classifier.process(deviceMotion: new_data)
                speaker_classifier.process(deviceMotion: new_data)
                self.motion_state = self.motion_classifier.results[0].0
                self.speaker_state = speaker_classifier.results[0].0
            } else {
                print(error!)
            }
        }
    }
    
    func stopMotionRecognition(){
        manager.stopDeviceMotionUpdates()
    }
}
