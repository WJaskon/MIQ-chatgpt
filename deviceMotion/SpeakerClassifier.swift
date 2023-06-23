//
//  MotionClassifier.swift
//  earableAIassistant
//
//  Created by sezaki on 2023/05/02.
//

import Foundation
import CoreMotion
import CoreML


class SpeakerClassifier{
    var results: [(String, Double)]
    
    init(){
        results = [("", 0.0)]
    }
    
    static let configuration = MLModelConfiguration()
    let model = try! earableAIassistant_acceleration(configuration: configuration)
    static let predictionWindowSize = 100
    static let stateInLength = 400
    
    let acceleration_x = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let acceleration_y = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let acceleration_z = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    var stateOut = try! MLMultiArray(shape:[stateInLength as NSNumber], dataType: MLMultiArrayDataType.double)
//    var stateOut: MLMultiArray? = nil
    
    private var predictionWindowIndex = 0
    
    func process(deviceMotion: CMDeviceMotion) {
        
        if predictionWindowIndex == MotionClassifier.predictionWindowSize {
            return
        }
        
        acceleration_x[[predictionWindowIndex] as [NSNumber]] = deviceMotion.userAcceleration.x as NSNumber
        acceleration_y[[predictionWindowIndex] as [NSNumber]] = deviceMotion.userAcceleration.y as NSNumber
        acceleration_z[[predictionWindowIndex] as [NSNumber]] = deviceMotion.userAcceleration.z as NSNumber
        
        predictionWindowIndex += 1
        
        if predictionWindowIndex == MotionClassifier.predictionWindowSize{
            print("predict")
            self.predict()
            self.predictionWindowIndex = 0
        }
    }
    
    
    private func predict(){
        let input = earableAIassistant_accelerationInput(
            acceleration_x: acceleration_x,
            acceleration_y: acceleration_y,
            acceleration_z: acceleration_z,
            stateIn: self.stateOut
        )
        
        guard let result = try? model.prediction(input: input) else { return }
//        stateOut = result.stateOut
        let sorted = result.labelProbability.sorted {
            return $0.value > $1.value
        }
        print(sorted)
        results = sorted
    }
}
