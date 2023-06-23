//
//  RecognitionService.swift
//  concurrent_test
//
//  Created by sezaki on 2023/06/07.
//

import SwiftUI
import Foundation
import CoreMotion
import Speech

class RecognitionService{
    private let manager = CMHeadphoneMotionManager()
    private let motion_classifier = MotionClassifier()
    private let speaker_classifier = SpeakerClassifier()
    var motion_state = "motion_state"
    var speaker_state = "speaker_state"
    
    init(){
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP])
            try audioSession.setActive(true)
        } catch {
            print("音声セッションの設定エラー：\(error)")
        }
        
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    }
    
    //MARK: motion recognition
    
    func startMotionRecognition(){
        manager.startDeviceMotionUpdates(to: OperationQueue()){ data, error in
            if error == nil {
                guard let new_data = data else {return}
                self.motion_classifier.process(deviceMotion: new_data)
                self.speaker_classifier.process(deviceMotion: new_data)
                self.motion_state = self.motion_classifier.results[0].0
                self.speaker_state = self.speaker_classifier.results[0].0
            } else {
                print(error!)
            }
        }
    }
    
    func stopMotionRecognition(){
        manager.stopDeviceMotionUpdates()
    }
    
    //MARK: Speech Recognition
    
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer: SFSpeechRecognizer
    private let request = SFSpeechAudioBufferRecognitionRequest()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var isRecognitionInProgress = false
    private(set) var lastTranscription = ""
    private(set) var bestTranscription = ""
    private(set) var yourTalking = false
    var startDate = Date();
    var stopDate = Date();
    private var recognitionWaitTime:Double = 1
    var stopTimer:Timer? = nil
    private let chatGPT = ChatGPT()
    
    private(set) var db = conversationLog(capacity: 100)
    
    func startRecognition() {
        guard !isRecognitionInProgress else {
            return
        }
        
        isRecognitionInProgress = true
        
        if let timer = self.stopTimer{
            timer.invalidate()
        }
        
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            self.request.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("音声エンジンの開始エラー：\(error)")
        }
        if speechRecognizer.supportsOnDeviceRecognition {
            print("OnDevice Recognition: True")
            request.requiresOnDeviceRecognition = true
        } else {
            print("OnDevice Recognition: False")
            request.requiresOnDeviceRecognition = false
        }
        
        speechRecognizer.defaultTaskHint = .dictation
        
        var isBegin  = true
        recognitionTask = speechRecognizer.recognitionTask(with: request) { result, error in
            var isFinal = false
            if(isBegin){
                self.startDate = Date()
                isBegin = false
            }
            if let result = result {
                isFinal = result.isFinal
                if(result.bestTranscription.formattedString != ""){
                    self.lastTranscription = result.bestTranscription.formattedString
                }
            }
            
            self.stopTimer?.invalidate()
            
            if (self.recognitionWaitTime > 0) {
                self.stopTimer = Timer.scheduledTimer(
                    withTimeInterval:self.recognitionWaitTime,
                    repeats: false,
                    block: { (timer) in
                        if let task = self.recognitionTask{
                            task.finish()
                        }
                    })
            }else{
                print("[NOTE] waitTime less than and equal 0. A Stop timer is not running.")
            }
            
            if error != nil || isFinal {
                self.stopTimer?.invalidate()
                self.stopDate = Date()
                self.bestTranscription = self.lastTranscription
                
                if(self.speaker_classifier.isTalking(startDate: self.startDate, stopDate: self.stopDate)){
                    self.yourTalking = true
                }else{
                    self.yourTalking = false
                }
                self.stopRecognition()
                self.startRecognition()
                
            }
        }
    }
    
    func stopRecognition() {
        if let timer = self.stopTimer{
            timer.invalidate()
        }
        
        if isRecognitionInProgress {
            audioEngine.stop()
            request.endAudio()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionTask?.cancel()
            recognitionTask = nil
            isRecognitionInProgress = false
            lastTranscription = ""
        }
    }
    
    public struct conversationLog {
        let capacity: Int
        private var buffer:[(String, Bool)]
        private(set) public var index = 0
        
        public init(capacity: Int) {
            self.capacity = capacity
            self.buffer = Array(repeating: ("", true), count: capacity)
        }
        
        public mutating func write(_ value: (String, Bool)) {
            buffer[index] = value
            index += 1
        }
        
        
        subscript(index: Int) -> (String, Bool) {
            get {
                return buffer[index]
            }
        }
    }
}
