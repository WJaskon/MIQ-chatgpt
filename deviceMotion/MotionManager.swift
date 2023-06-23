//
//  File.swift
//  earableAIassistant
//
//  Created by sezaki on 2023/04/27.
//


import CoreMotion
import SwiftUI


final class MotionManager {
    var manager: CMHeadphoneMotionManager?
    
    init() {
        manager = CMHeadphoneMotionManager()
    }
    
    func startUpdate(completion: @escaping (CMDeviceMotion?) -> Void) {
        guard let manager = manager else {
            return
        }
        
        if manager.isDeviceMotionAvailable {
            manager.startDeviceMotionUpdates(to: OperationQueue.main) { data, error in
                if error == nil {
                    print(data)
                    completion(data)
                } else {
                    // エラー対応
                }
            }
        }else{
            print("not available")
            return
        }
    }
    
    func stopUpdate() {
        manager?.stopDeviceMotionUpdates()
    }
}
