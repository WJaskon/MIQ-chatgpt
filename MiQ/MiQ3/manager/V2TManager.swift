//
//  SpeechManager.swift
//  MiQ
//
//  Created by Yuuki Nishiyama on 2021/05/15.
//  Copyright © 2019 Yuuki Nishiyama. All rights reserved.
//


// NOTE
// https://developer.apple.com/documentation/speech
// https://developer.apple.com/videos/play/wwdc2019/256
// https://qiita.com/mtfum/items/d842c8f5a0e5b99fa4ad

import UIKit
import Foundation
import Speech
import MediaPlayer
import Accelerate
import CoreData
import CoreMotion

protocol V2TManagerDelegate {
    func didFinishSpeechRecognition(result:String?, backupAudioFile:URL?);
    func didUpdateSpeechRecognition(progress:String?);
    func didDetectHowWord();
}

class V2TManager:NSObject, SFSpeechRecognizerDelegate, ObservableObject {
    public var delegate:V2TManagerDelegate?
    
    //    private let hotWordDetector = HotWordDetecor()
    
    // speech to text
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    private var audioFile:AVAudioFile?
    private var k44mixer = AVAudioMixerNode()
    
    private var recognitionHint:SFSpeechRecognitionTaskHint = .dictation
    private var recognitionWaitTime:Double = 0
    private var contextualStrings:[String] = []
    
    var stagedText    = ""
    var stopTimer:Timer? = nil
    var bootRecognitionTask = false
    
    @Published var bestTranscription = ""
    @Published var errorMsg:Error?
    
    var progressCallback:((String?)->Void)? = nil
    var resultCallback:((String?, URL?)->Void)? = nil
    var earphoneEventHandler:(()->Void)?=nil
    var decibelMonitor:((Float)->Void)?=nil
    var rmsMonitor:((Float)->Void)?=nil
    var fftMonitor:(([Float])->Void)?=nil
    
    private var needHotWord = false
    
    var transModel:TranscriptionModel?
    
    var startDate = Date()
    var stopDate = Date()
    
    //for motion data
    var manager: CMHeadphoneMotionManager?
    private let classfier = TalkingClassifier()
    
    public func hasRecognitionTask() -> Bool {
        if (recognitionTask == nil) {
            return false
        }else{
            return true
        }
    }
    
    var context:NSManagedObjectContext?
    var exerciseSession:EntityExerciseSession?
    
    init(_ context:NSManagedObjectContext?=nil) {
        self.context = context
        super.init()
        speechRecognizer.delegate = self
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    break
                case .denied:
                    break
                case .restricted:
                    break
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
    
    //    convenience init(hint:SFSpeechRecognitionTaskHint = .unspecified,
    //                     waitTime:Double = 0,
    //                     contextualStrings:[String]=[]){
    //        self.init()
    //        self.recognitionHint = hint
    //        self.recognitionWaitTime = waitTime
    //        self.contextualStrings = contextualStrings
    //    }
    //
    deinit {
        stopSpeechRecognition()
        audioEngine.inputNode.removeTap(onBus: 0)
        self.audioEngine.reset()
        manager = CMHeadphoneMotionManager()
    }
    
    public func getMicrophones() -> [AVAudioSessionPortDescription]? {
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord,
                                         mode: .voiceChat,
                                         options: [
                                            //                                                    .defaultToSpeaker,
                                            //                                                   .allowBluetoothA2DP,
                                            //                                                   .allowAirPlay,
                                            .allowBluetooth
                                         ])
            try audioSession.setActive(true)
            return audioSession.availableInputs
        } catch {
            return nil
        }
    }
    
    public func startSession(hotword:Bool = false,
                             bootRecognitionTask:Bool = true,
                             hint:SFSpeechRecognitionTaskHint? = nil,
                             waitTime:Double? = nil,
                             autoReboot:Bool = false,
                             locale:String?,
                             contextualStrings:[String]? = nil,
                             earphoneEventHandler:(()->Void)? = nil,
                             progressCallback:((String?)->Void)? = nil,
                             resultCallback:((String?, URL?)->Void)? = nil) throws {
        
        self.earphoneEventHandler = earphoneEventHandler
        addRemoteCommandEvents()
        
        if let loc = locale {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: loc))!
        }
        self.bootRecognitionTask = bootRecognitionTask
        self.progressCallback = progressCallback
        self.resultCallback = resultCallback
        self.needHotWord = hotword
        if let hint = hint {
            self.recognitionHint = hint
        }
        
        if let waitTime = waitTime {
            self.recognitionWaitTime = waitTime
        }
        
        if let contextualStrings = contextualStrings {
            self.contextualStrings = contextualStrings
        }
        
        if let c = context {
            let date = Date()
            self.exerciseSession = EntityExerciseSession(context: c)
            self.exerciseSession?.created_at = date
            self.exerciseSession?.modified_at = date
            self.exerciseSession?.start_at = date
            self.exerciseSession?.end_at = date
            self.exerciseSession?.timestamp = date.timeIntervalSince1970
            do {
                try c.save()
            }catch{
                print("error: \(error.localizedDescription)")
            }
        }
        
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.finish()
            self.audioEngine.inputNode.removeTap(onBus: 0)
            self.audioEngine.reset()
        }
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord,
                                     mode: .voiceChat,
                                     options: [
                                        //                                        .defaultToSpeaker
                                        //                                        .allowBluetoothA2DP,
                                        //                                               .allowAirPlay,
                                        .allowBluetooth
                                     ])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // bluetoothのマイクを積極的に使うようにする
        if let inputs = audioSession.availableInputs {
            for input in inputs{
                print(input)
                switch input.portType {
                case .bluetoothLE, .bluetoothHFP, .bluetoothA2DP:
                    try audioSession.setPreferredInput(input)
                    break
                default:
                    break
                }
            }
        }
        
        let inputNode    = audioEngine.inputNode
        print(inputNode)
        let inputFormat = inputNode.inputFormat(forBus: 0)
        print(inputFormat)
        
        inputNode.installTap(onBus: 0,
                             bufferSize: 16384, // 8192, //4096, // //32768, //1024,
                             format: inputFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            // speech recognition
            self.recognitionRequest?.append(buffer)
            
            
            if let audioData = buffer.floatChannelData?[0] {
                let frames = buffer.frameLength
                if let rsmMonitor = self.rmsMonitor {
                    let rms = SignalProcessing.rms(data: audioData, frameLength: UInt(frames))
                    rsmMonitor(rms)
                }
                if let dbMonitor = self.decibelMonitor {
                    let rms = SignalProcessing.rms(data: audioData, frameLength: UInt(frames))
                    let db = SignalProcessing.db(from: rms)
                    dbMonitor(db)
                }
                if let monitor = self.fftMonitor {
                    let fftMagnitudes = SignalProcessing.fft(buffer)
                    monitor(fftMagnitudes)
                }
            }
            
            
            // record speech
            do{
                try self.audioFile?.write(from: buffer)
            }catch{
                print("Error: The target audio file does not exit.")
            }
            
            //            if (self.needHotWord){
            //                // Detect the hotword
            //                if self.recognitionTask == nil {
            //                    let convertedBuffer:AVAudioPCMBuffer? = self.hotWordDetector.convert(buffer: buffer, inputFormat: inputFormat)
            //
            //                    if let newbuffer = convertedBuffer{
            //                        // Detect the hotword from audio buffer
            //                        let array = Array(UnsafeBufferPointer(start: newbuffer.floatChannelData?[0], count:Int(newbuffer.frameLength)))
            //                        let result = self.hotWordDetector.wrapper.runDetection(array, length: Int32(newbuffer.frameLength))
            //                        /// 1 = detected, 0 = other voice or noise, -2 = no voice and noise
            //                        if result == 1 {
            //                            self.delegate?.didDetectHowWord();
            //                        }
            //                    }
            //                }
            //            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        if (!self.needHotWord && bootRecognitionTask){
            do {
                try self.startSpeechRecognition()
            }catch {
                print(error)
            }
        }
    }
    
    public func stopSession(){
        self.removeRemoteCommandEvents()
        self.audioEngine.stop()
        self.audioEngine.disconnectNodeOutput(audioEngine.inputNode)
        self.audioEngine.inputNode.removeTap(onBus: 0)
        self.audioEngine.reset()
        self.resultCallback = nil
        self.earphoneEventHandler = nil
        self.progressCallback = nil
        self.decibelMonitor = nil
        self.rmsMonitor = nil
        self.fftMonitor = nil
    }
    
    
    public func startSpeechRecognition() throws {
        
        
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            print("\(#function): init recognitionTask")
            recognitionTask.finish()
            recognitionTask.cancel()
            self.recognitionTask = nil
            self.audioFile = nil
        }
        
        self.errorMsg = nil
        
        if let timer = self.stopTimer{
            timer.invalidate()
        }
        
        let inputNode = audioEngine.inputNode
        
        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object")
        }
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionRequest.contextualStrings = contextualStrings
        recognitionRequest.taskHint = recognitionHint
        
        if speechRecognizer.supportsOnDeviceRecognition {
            print("OnDevice Recognition: True")
            recognitionRequest.requiresOnDeviceRecognition = true
        }else {
            print("OnDevice Recognition: False")
        }
        
        var isBegin  = true
        
        // Create a recognition task for the speech recognition session.
        // Keep a reference to the task so that it can be canceled.
//        DispatchQueue.global(){
//
//        }
        recognitionTask  = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            print("startSpeechRecognition: "+String(Thread.current.isMainThread))
            var isFinal  = false
            
            if(isBegin){
                self.startDate = Date()
                isBegin = false
            }
            
            if let result = result {
                isFinal = result.isFinal
                if(result.bestTranscription.formattedString != ""){
                    self.bestTranscription = result.bestTranscription.formattedString
                    self.delegate?.didUpdateSpeechRecognition(progress: self.bestTranscription)
                    self.progressCallback?(self.bestTranscription)

                    if (self.transModel == nil) {
                        if let c = self.context {
                            self.transModel = TranscriptionModel(result,
                                                                 self.audioFile?.url,
                                                                 c)
                            if let voiceMemo = self.transModel?.voiceMemo {
                                self.exerciseSession?.end_at = Date()
                                self.exerciseSession?.addToVoice_memos(voiceMemo)
                                do {
                                    try c.save()
                                } catch {
                                    print("error")
                                }
                            }
                        }
                    }else{
                        self.transModel?.addTranscription( result,
                                                           self.audioFile?.url)
                    }
                }
                
            }
            
            // Reset an audio recognition
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
            
            if isFinal {
                
                self.stopTimer?.invalidate()
                self.stopSpeechRecognition()
                self.transModel = nil
                
                DispatchQueue.main.async {
                    if (self.bootRecognitionTask) {
                        do {
                            try self.startSpeechRecognition()
                        } catch {
                            print("[ERROR]: ", error.localizedDescription)
                            self.errorMsg = error
                        }
                    }
                }
            }
            
            if error != nil {
                // http://harumi.sakura.ne.jp/wordpress/2020/04/20/speechframework%E3%81%A7%E9%9F%B3%E5%A3%B0%E8%AA%8D%E8%AD%98%E3%81%95%E3%82%8C%E3%81%AA%E3%81%8F%E3%81%AA%E3%82%8B%E5%95%8F%E9%A1%8C/
                self.stopTimer?.invalidate()
                self.stopSpeechRecognition()
                self.transModel = nil
                
                if let e = error {
                    if (e.code == 1101) {
                        print("[Fin] \(self.bestTranscription)")
                        // self.errorMsg = e
                    }else{
                        print("[ERROR!!!]: ", e.localizedDescription)
                        self.errorMsg = e
                        
                        DispatchQueue.main.async {
                            if (self.bootRecognitionTask) {
                                do {
                                    try self.startSpeechRecognition()
                                } catch {
                                    print("[ERROR]: ", error.localizedDescription)
                                    self.errorMsg = error
                                }
                            }
                        }
                    }
                }
            }
            
        }
        
        let outputFormat = inputNode.outputFormat(forBus: 0)
        let timestamp = "\(Int(Date().timeIntervalSince1970)).wav"
        audioFile = try AVAudioFile(forWriting: getAudioFileUrl(fileName: timestamp),
                                    settings: outputFormat.settings,
                                    commonFormat: outputFormat.commonFormat,
                                    interleaved: false)
    }
    
    public func stopSpeechRecognition(){
        if let timer = self.stopTimer{
            timer.invalidate()
        }
        
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            recognitionTask.finish()
            self.recognitionTask = nil
        }
        
        if let recognitionRequest = self.recognitionRequest{
            recognitionRequest.endAudio()
            self.recognitionRequest = nil
        }
        
        self.stopDate = Date()
        if(self.bestTranscription != ""){
            print(self.startDate, "-", self.stopDate, self.bestTranscription)
        }
        
        
        self.delegate?.didFinishSpeechRecognition(result: self.bestTranscription,
                                                  backupAudioFile: self.audioFile?.url)
        self.resultCallback?(self.bestTranscription, self.audioFile?.url)
        
        
        self.audioFile = nil
        self.bestTranscription = ""
    }
    
    
    func getAudioFileUrl(fileName:String="recording.wav") -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docsDirect = paths[0]
        let audioUrl = docsDirect.appendingPathComponent(fileName)
        
        return audioUrl
    }
    
    
    var pauseHandler:Any?
    //    var playHandler:Any?
    //    var playPauseHandler:Any?
    
    // MARK: Remote Command Event
    func addRemoteCommandEvents() {
        let commandCenter = MPRemoteCommandCenter.shared()
        pauseHandler = commandCenter.pauseCommand.addTarget { [unowned self] commandEvent in
            self.remotePause(commandEvent)
            return .success
        }
        
        //        playHandler = commandCenter.playCommand.addTarget{ [unowned self] commandEvent in
        //            self.remotePlay(commandEvent)
        //            return .success
        //        }
        //        playPauseHandler = commandCenter.togglePlayPauseCommand.addTarget{ [unowned self] commandEvent in
        //            self.remoteTogglePlayPause(commandEvent)
        //            return .success
        //        }
    }
    
    func removeRemoteCommandEvents(){
        let commandCenter = MPRemoteCommandCenter.shared()
        if let handler = self.pauseHandler {
            commandCenter.pauseCommand.removeTarget(handler)
        }
        //        if let handler = self.playHandler {
        //            commandCenter.playCommand.removeTarget(handler)
        //        }
        //        if let handler = self.playPauseHandler  {
        //            commandCenter.togglePlayPauseCommand.removeTarget(handler)
        //        }
    }
    
    func remoteTogglePlayPause(_ event: MPRemoteCommandEvent) {
        print(#function)
    }
    
    func remotePlay(_ event: MPRemoteCommandEvent) {
        print(#function)
    }
    
    func remotePause(_ event: MPRemoteCommandEvent) {
        print(#function)
        if let handler = self.earphoneEventHandler {
            handler()
        }
    }
    
    
    func transcribeAudio(url: URL) -> String? {
        // create a new recognizer and point it at our audio
        //        let recognizer = SFSpeechRecognizer()
        let request = SFSpeechURLRecognitionRequest(url: url)
        print(url)
        var resultStr:String?
        // start recognition!
        self.speechRecognizer.recognitionTask(with: request) { (result, error) in
            // abort if we didn't get any transcription back
            guard let result = result else {
                print("There was an error: \(error!)")
                return
            }
            print(result.bestTranscription.formattedString)
            // if we got the final transcription back, print it
            if result.isFinal {
                // pull out the best transcription...
                print(result.bestTranscription.formattedString)
                resultStr = result.bestTranscription.formattedString
            }
        }
        
        return resultStr
    }
}


//https://betterprogramming.pub/audio-visualization-in-swift-using-metal-accelerate-part-1-390965c095d7

class SignalProcessing {
    static func rms(data: UnsafeMutablePointer<Float>, frameLength: UInt) -> Float {
        var val : Float = 0
        vDSP_measqv(data, 1, &val, frameLength)
        return val
    }
    
    static func db(from rms:Float) -> Float {
        //inverse dB to +ve range where 0(silent) -> 160(loudest)
        return 10*log10f(rms)
    }
    
    //    static func fft(data: UnsafeMutablePointer<Float>, setup: OpaquePointer) -> [Float] {
    //        //output setup
    //        var realIn = [Float](repeating: 0, count: 1024)
    //        var imagIn = [Float](repeating: 0, count: 1024)
    //        var realOut = [Float](repeating: 0, count: 1024)
    //        var imagOut = [Float](repeating: 0, count: 1024)
    //
    //        //fill in real input part with audio samples
    //        for i in 0...1023 {
    //            realIn[i] = data[i]
    //        }
    //
    //
    //        vDSP_DFT_Execute(setup, &realIn, &imagIn, &realOut, &imagOut)
    //        //our results are now inside realOut and imagOut
    //
    //
    //        //package it inside a complex vector representation used in the vDSP framework
    //        var complex = DSPSplitComplex(realp: &realOut, imagp: &imagOut)
    //
    //        //setup magnitude output
    //        var magnitudes = [Float](repeating: 0, count: 512)
    //
    //        //calculate magnitude results
    //        vDSP_zvabs(&complex, 1, &magnitudes, 1, 512)
    //
    //        return magnitudes;
    //    }
    
    /// - Parameter buffer: Audio data in PCM format
    static func fft(_ buffer: AVAudioPCMBuffer) -> [Float] {
        
        let size: Int = Int(buffer.frameLength)
        
        /// Set up the transform
        let log2n = UInt(round(log2f(Float(size))))
        let bufferSize = Int(1 << log2n)
        
        /// Sampling rate / 2
        let inputCount = bufferSize / 2
        
        /// FFT weights arrays are created by calling vDSP_create_fftsetup (single-precision) or vDSP_create_fftsetupD (double-precision). Before calling a function that processes in the frequency domain
        let fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
        
        /// Create the complex split value to hold the output of the transform
        var realp = [Float](repeating: 0, count: inputCount)
        var imagp = [Float](repeating: 0, count: inputCount)
        var output = DSPSplitComplex(realp: &realp, imagp: &imagp)
        
        
        var transferBuffer = [Float](repeating: 0, count: bufferSize)
        vDSP_hann_window(&transferBuffer, vDSP_Length(bufferSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul((buffer.floatChannelData?.pointee)!, 1, transferBuffer,
                  1, &transferBuffer, 1, vDSP_Length(bufferSize))
        
        let temp = UnsafePointer<Float>(transferBuffer)
        
        temp.withMemoryRebound(to: DSPComplex.self, capacity: transferBuffer.count) { (typeConvertedTransferBuffer) -> Void in
            vDSP_ctoz(typeConvertedTransferBuffer, 2, &output, 1, vDSP_Length(inputCount))
        }
        /// Do the fast Fournier forward transform
        vDSP_fft_zrip(fftSetup!, &output, 1, log2n, Int32(FFT_FORWARD))
        
        /// Convert the complex output to magnitude
        var magnitudes = [Float](repeating: 0.0, count: inputCount)
        vDSP_zvmags(&output, 1, &magnitudes, 1, vDSP_Length(inputCount))
        
        var normalizedMagnitudes = [Float](repeating: 0.0, count: inputCount)
        vDSP_vsmul(sqrtq(magnitudes), 1, [2.0/Float(inputCount)],
                   &normalizedMagnitudes, 1, vDSP_Length(inputCount))
        
        //        print("Normalized magnitudes: \(magnitudes)")
        
        /// Release the setup
        vDSP_destroy_fftsetup(fftSetup)
        
        return normalizedMagnitudes
        
    }
    
    static func sqrtq(_ x: [Float]) -> [Float] {
        var results = [Float](repeating: 0.0, count: x.count)
        vvsqrtf(&results, x, [Int32(x.count)])
        
        return results
    }
    
}

extension Error {
    var code: Int { return (self as NSError).code }
    var domain: String { return (self as NSError).domain }
}
