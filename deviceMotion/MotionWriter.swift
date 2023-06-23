//
//  MotionWriter.swift
//  earableAIassistant
//
//  Created by sezaki on 2023/04/29.
//

import Foundation
import CoreMotion

class MotionWriter {
    var manager: CMHeadphoneMotionManager?
    
    init() {
        manager = CMHeadphoneMotionManager()
    }
    
    var text = ""
    var cnt = 0
    
    
    func startWrite(){
        guard let manager = manager else {
            return
        }
        
        self.open()
        
        if !manager.isDeviceMotionAvailable{
            print("current device does not supports the headphone motion manager.")
        }
        print("start")
        manager.startDeviceMotionUpdates(to: OperationQueue.main) { data, error in
            if error == nil{
                guard let new_data = data else {return}
                print(new_data)
                self.write(new_data)
            } else {print(error)}
            
        }
        
    }
    
    func open() {
        text += "timestamp, "
        text += "acceleration_x,"
        text += "acceleration_y,"
        text += "acceleration_z,"
        text += "attitude_pitch,"
        text += "attitude_roll,"
        text += "attitude_yaw,"
        text += "gravity_x,"
        text += "gravity_y,"
        text += "gravity_z,"
        text += "quaternion_x,"
        text += "quaternion_y,"
        text += "quaternion_z,"
        text += "quaternion_w,"
        text += "rotation_x,"
        text += "rotation_y,"
        text += "rotation_z"
        text += "\n"
    }
    
    func write(_ motion: CMDeviceMotion) {
        text += "\(motion.timestamp), "
        text += "\(motion.userAcceleration.x),"
        text += "\(motion.userAcceleration.y),"
        text += "\(motion.userAcceleration.z),"
        text += "\(motion.attitude.pitch),"
        text += "\(motion.attitude.roll),"
        text += "\(motion.attitude.yaw),"
        text += "\(motion.gravity.x),"
        text += "\(motion.gravity.y),"
        text += "\(motion.gravity.z),"
        text += "\(motion.attitude.quaternion.x),"
        text += "\(motion.attitude.quaternion.y),"
        text += "\(motion.attitude.quaternion.z),"
        text += "\(motion.attitude.quaternion.w),"
        text += "\(motion.rotationRate.x),"
        text += "\(motion.rotationRate.y),"
        text += "\(motion.rotationRate.z)"
        text += "\n"
    }
    
    func stopWrite() {
        manager?.stopDeviceMotionUpdates()
        let fileManager = FileManager.default
        let filePath = NSHomeDirectory() + "/Documents" + "/\(createPath())" + ".csv"
        let csv = text
        let data = csv.data(using: .utf8)
        if !fileManager.fileExists(atPath: filePath) {
            fileManager.createFile(atPath:filePath, contents: data, attributes: [:])
        }else{
            print("既に存在します。")
        }
        print("created")
        text = ""
    }
    
    private func createPath() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        
        let strDate = formatter.string(from: date)
        return strDate
    }
}
