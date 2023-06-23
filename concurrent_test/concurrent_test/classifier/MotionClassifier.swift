//
//  MotionClassifier.swift
//  earableAIassistant
//
//  Created by sezaki on 2023/05/02.
//

import Foundation
import CoreMotion
import CoreML

class MotionClassifier{
    var manager: CMHeadphoneMotionManager?
    var results: [(String, Double)]
    
    init(){
        manager = CMHeadphoneMotionManager()
        results = [("", 0.0)]
        stateOut.zeroInit()
    }
    
    static let configuration = MLModelConfiguration()
    let model = try! command_classifier(configuration: configuration)
    static let predictionWindowSize = 15
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
    let rotation_x = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let rotation_y = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let rotation_z = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let quaternion_w = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let quaternion_x = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let quaternion_y = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    let quaternion_z = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    var stateOut = try! MLMultiArray(shape:[stateInLength as NSNumber], dataType: MLMultiArrayDataType.double)
    
    private var predictionWindowIndex = 0
    
    func process(deviceMotion: CMDeviceMotion) {
        
        if predictionWindowIndex == MotionClassifier.predictionWindowSize {
            return
        }
        
        acceleration_x[[predictionWindowIndex] as [NSNumber]] = deviceMotion.userAcceleration.x as NSNumber
        acceleration_y[[predictionWindowIndex] as [NSNumber]] = deviceMotion.userAcceleration.y as NSNumber
        acceleration_z[[predictionWindowIndex] as [NSNumber]] = deviceMotion.userAcceleration.z as NSNumber
        rotation_x[[predictionWindowIndex] as [NSNumber]] = deviceMotion.rotationRate.x as NSNumber
        rotation_y[[predictionWindowIndex] as [NSNumber]] = deviceMotion.rotationRate.y as NSNumber
        rotation_z[[predictionWindowIndex] as [NSNumber]] = deviceMotion.rotationRate.z as NSNumber
        quaternion_w[[predictionWindowIndex] as [NSNumber]] = deviceMotion.attitude.quaternion.w as NSNumber
        quaternion_x[[predictionWindowIndex] as [NSNumber]] = deviceMotion.attitude.quaternion.x as NSNumber
        quaternion_y[[predictionWindowIndex] as [NSNumber]] = deviceMotion.attitude.quaternion.y as NSNumber
        quaternion_z[[predictionWindowIndex] as [NSNumber]] = deviceMotion.attitude.quaternion.z as NSNumber
        
        predictionWindowIndex += 1
        
        if predictionWindowIndex == MotionClassifier.predictionWindowSize{
            self.predict()
            predictionWindowIndex = 0
        }
    }
    
    
    private func predict(){
        let input = command_classifierInput(
            acceleration_x: acceleration_x,
            acceleration_y: acceleration_y,
            acceleration_z: acceleration_z,
            quaternion_w: quaternion_w,
            quaternion_x: quaternion_x,
            quaternion_y: quaternion_y,
            quaternion_z: quaternion_z,
            rotation_x: rotation_x,
            rotation_y: rotation_y,
            rotation_z: rotation_z,
            stateIn: self.stateOut
        )
        
        guard let result = try? model.prediction(input: input) else { return }
        //stateOut = result.stateOut
        let sorted = result.labelProbability.sorted {
            return $0.value > $1.value
        }
        results = sorted
    }
}
