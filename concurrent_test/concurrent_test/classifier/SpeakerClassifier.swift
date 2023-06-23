//
//  MotionClassifier.swift
//  earableAIassistant
//
//  Created by sezaki on 2023/05/02.
//

import Foundation
import CoreMotion
import CoreML

extension MLMultiArray {
    public func zeroInit() {
        let ptr = self.dataPointer.bindMemory(to: Double.self, capacity: self.count)
        let ptr_buf = UnsafeMutableBufferPointer.init(start: ptr, count: self.count)
        let zeros = repeatElement(Double(0.0), count: self.count)
        _ = ptr_buf.initialize(from: zeros)
    }
}


class SpeakerClassifier{
    var results: [(String, Double)]
    var date = Date()
    let dateFormatter = DateFormatter()
    
    //ring buffer
    private(set) var data = RingBuffer(capacity: 50)
    
    static let configuration = MLModelConfiguration()
    let model = try! speaker_classifier(configuration: configuration)
    static let predictionWindowSize = 20
    static let stateInLength = 400
    
    let rotation_x = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let rotation_y = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let rotation_z = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    var stateOut = try! MLMultiArray(shape:[stateInLength as NSNumber], dataType: MLMultiArrayDataType.double)
    
//    var stateOut = try! MLMultiArray(shape:[stateInLength as NSNumber], dataType: MLMultiArrayDataType.double)
//    var stateOut: MLMultiArray? = nil
    
    private var predictionWindowIndex = 0
    
    init(){
        results = [("", 0.0)]
        stateOut.zeroInit()
    }
    
    func process(deviceMotion: CMDeviceMotion) {
        
        if predictionWindowIndex == SpeakerClassifier.predictionWindowSize {
            return
        }
        
        rotation_x[[predictionWindowIndex] as [NSNumber]] = deviceMotion.rotationRate.x as NSNumber
        rotation_y[[predictionWindowIndex] as [NSNumber]] = deviceMotion.rotationRate.y as NSNumber
        rotation_z[[predictionWindowIndex] as [NSNumber]] = deviceMotion.rotationRate.z as NSNumber
        
        predictionWindowIndex += 1
        
        if predictionWindowIndex == SpeakerClassifier.predictionWindowSize{
            date = Date()
            self.predict()
            self.predictionWindowIndex = 0
        }
    }
    
    
    private func predict(){
        let input = speaker_classifierInput(
            rotation_x: rotation_x,
            rotation_y: rotation_y,
            rotation_z: rotation_z,
            stateIn: self.stateOut
        )
        
        guard let result = try? model.prediction(input: input) else { return }
//        stateOut = result.stateOut
        results = result.labelProbability.sorted {
            return $0.value > $1.value
        }
        
        if results[0].0 == "conversation"{
            data.write((date, true))
        }else{
            data.write((date, false))
        }
    }
    
    public func isTalking(startDate: Date, stopDate: Date) -> Bool{
        var sum = 0.0
        var cnt = 0.0
        for i in data.oldestIndex..<data.latestIndex{
            if data[i].0 > stopDate{
                break
            }
            if data[i].0 > startDate{
                if data[i].1{
                    sum += 1
                }
                cnt += 1
            }
        }
        let ave = sum/cnt
        if(ave >= 0.5){
            return true
        }else{
            return false
        }
    }
    
    public struct RingBuffer {
        let capacity: Int
        private var buffer:[(Date, Bool)]
        private(set) public var latestIndex: Int = -1
        private(set) public var oldestIndex: Int = 0
        let d = Date()
        public var count: Int {
            return (latestIndex - oldestIndex + 1)
        }
        
        public init(capacity: Int) {
            self.capacity = capacity
            self.buffer = Array(repeating: (d, true), count: capacity)
        }
        
        public mutating func write(_ value: (Date, Bool)) {
            latestIndex += 1
            buffer[latestIndex % capacity] = value
            if capacity == count {
                oldestIndex += 1
            }
        }
        
        
        subscript(index: Int) -> (Date, Bool) {
            get {
                return buffer[index % capacity]
            }
        }
    }
}

