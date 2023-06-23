//
//  AudioManager.swift
//  MiQWatch Extension
//
//  Created by Yuuki Nishiyama on 2021/06/01.
//

import UIKit
import Foundation
import MediaPlayer
import Accelerate
import AVFoundation

extension AudioManager: AVAudioPlayerDelegate{
    
}

public class AudioManager:NSObject, AVAudioRecorderDelegate {

    private var audioEngine = AVAudioEngine()
    private var audioFile:AVAudioFile?
    private var k44mixer = AVAudioMixerNode()
    // private var audioRecorder: AVAudioRecorder?

    private var recognitionWaitTime:Double = 0
    private var contextualStrings:[String] = []
    
    var stagedText    = ""
    var stopTimer:Timer? = nil
    var bestTranscription = ""
    
    var earphoneEventHandler:(()->Void)?=nil
    var decibelMonitor:((Float)->Void)?=nil
    var rmsMonitor:((Float)->Void)?=nil
    var fftMonitor:(([Float])->Void)?=nil
    
    var audioRecorder: AVAudioRecorder!
    var audioPlayer: AVAudioPlayer!
    var isRecording = false
    var isPlaying = false
    
    private var needHotWord = false

    deinit {
        audioEngine.inputNode.removeTap(onBus: 0)
        self.audioEngine.reset()
    }
    
    public func startSession(fileUrl:URL? = nil,
                             earphoneEventHandler:(()->Void)? = nil,
                             decibelMonitor:((Float)->Void)? = nil
                             ) throws {
        self.earphoneEventHandler = earphoneEventHandler
        self.decibelMonitor = decibelMonitor
        
        addRemoteCommandEvents()
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord,
                                     mode: .voiceChat,
                                     options: [.allowBluetoothA2DP])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        let inputNode    = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        
        inputNode.installTap(onBus: 0,
                             bufferSize: 8192, //16384, // 8192, //4096, // //32768, //1024,
                             format: inputFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            
            /// Returns the peak power, in decibels full-scale (dBFS), for an audio channel.
            ///
            /// The audio channel whose peak power value you want to obtain.
            /// Channel numbers are zero-indexed. A monaural signal, or the left channel of a stereo signal, has channel number 0.
//            self.audioRecorder.updateMeters()
//            print("AudioRecorder => \t", self.audioRecorder.peakPower(forChannel: 0), self.audioRecorder.averagePower(forChannel: 0))
            
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
            
//            do{
//                try self.audioFile?.write(from: buffer)
//            }catch{
//                print("Error: The target audio file does not exit.")
//            }
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    
        // 保存する音声ファイルの準備
        
        if let fileUrl = fileUrl {
            let outputFormat = inputNode.outputFormat(forBus: 0)
//            audioFile = try AVAudioFile(forWriting:  fileUrl,
//                                        settings: outputFormat.settings,
//                                         commonFormat: outputFormat.commonFormat,
//                                         interleaved: true)
            do {
                audioRecorder = try AVAudioRecorder(url: fileUrl, settings: outputFormat.settings)
                audioRecorder.delegate = self
                audioRecorder.record()
                audioRecorder.isMeteringEnabled = true
            } catch  {
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
        if (self.audioRecorder != nil) {
            self.audioRecorder.stop()
        }
        self.earphoneEventHandler = nil
        self.decibelMonitor = nil
        self.rmsMonitor = nil
        self.fftMonitor = nil
    }

    
    var pauseHandler:Any?
    
   // MARK: Remote Command Event
   func addRemoteCommandEvents() {
        let commandCenter = MPRemoteCommandCenter.shared()
        pauseHandler = commandCenter.pauseCommand.addTarget(handler: { [unowned self] commandEvent -> MPRemoteCommandHandlerStatus in
           self.remotePause(commandEvent)
           return MPRemoteCommandHandlerStatus.success
       })

   }
    
    func removeRemoteCommandEvents(){
        let commandCenter = MPRemoteCommandCenter.shared()
        if let handler = self.pauseHandler {
            commandCenter.pauseCommand.removeTarget(handler)
        }
    }
//
//   func remoteTogglePlayPause(_ event: MPRemoteCommandEvent) {
//    print(#function)
//   }
//
//   func remotePlay(_ event: MPRemoteCommandEvent) {
//    print(#function)
//   }
//
   func remotePause(_ event: MPRemoteCommandEvent) {
    print(#function)
    if let handler = self.earphoneEventHandler {
        handler()
    }
   }
}


//https://betterprogramming.pub/audio-visualization-in-swift-using-metal-accelerate-part-1-390965c095d7

class SignalProcessing {

//    https://pebble8888.hatenablog.com/entry/2014/06/28/010205
//    https://macasakr.sakura.ne.jp/decibel4.html
    static func rms(data: UnsafeMutablePointer<Float>, frameLength: UInt) -> Float {
        var val : Float = 0
        vDSP_rmsqv(data, 1, &val, frameLength) // 要素の２乗の合計をNで割り平方根を取る
        return val
    }
    
    static func db(from rms:Float, base:Float=1) -> Float {
        /// 音圧レベルとは、音による気圧の差をデシベルで表示したものです。
        /// この場合、20μPaの音圧（気圧差）を基準値P0（0dB）として、以下の式で求められます。
        /// 音圧レベルLp=10log(P/P0)m2=20log(P/P0)
        return 20*log10f(rms/base)
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

