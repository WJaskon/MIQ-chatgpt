//
//  MotionSensorManager.swift
//  MiQWatch Extension
//
//  Created by Yuuki Nishiyama on 2021/06/01.
//

import WatchKit
import UIKit
import Foundation
import HealthKit
import CoreMotion
import CoreLocation
import CoreML
import WatchConnectivity

class SensorManager: NSObject, ObservableObject {
    
    @Published var sensorData:SensorData = SensorData()
    
    let healthStore = HKHealthStore()
    let motion = CMMotionManager()
    let location = CLLocation()
    var timer:Timer? = nil
    var altimeter = CMAltimeter()
    
    var session : HKWorkoutSession?
    let heartRateUnit = HKUnit(from: "count/min")
    var currenQuery : HKQuery?
    
    var deviceMotions = [CMDeviceMotion]()
    
    var isRunning = false
    var elapse = 0
    
    var classifier:BatSwingClassifier?
    public var classificationResultHandler:((BatSwingClassifierOutput, Double)->Void)?

    override init() {
        //        self.wcsession = wcsession
        //        super.init()
        //        self.wcsession.delegate = self
        //        self.wcsession.activate()
        do {
            classifier = try BatSwingClassifier(configuration: MLModelConfiguration())
        } catch {
            print(error)
        }
    }
    
    
    func initHealthKit(){
        guard HKHealthStore.isHealthDataAvailable() == true else {
            return
        }
        
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else {
            return
        }
        
        let dataTypes = Set(arrayLiteral: quantityType)
        healthStore.requestAuthorization(toShare: nil,
                                         read: dataTypes) { (success, error) -> Void in
        }
    }
    
    
    func start(){
        if (!isRunning) {
            sensorData = SensorData()
            deviceMotions = [CMDeviceMotion]()
            startWorkout()
            startMotionSensors(hz: 100)
        }
    }
    
    func stop(){
        if (isRunning) {
            if let workout = self.session {
                workout.end()
                stopMotionSensors()
            }
            if let timer = self.timer {
                timer.invalidate()
                self.timer = nil
            }
        }
    }
    
    
    func startMotionSensors(hz:Double){
        let interval = 1.0 / hz
        
        if self.motion.isAccelerometerAvailable{
            print("Start Acc sensors: interval = \(interval)")
            self.motion.accelerometerUpdateInterval = interval
            self.motion.startAccelerometerUpdates()
        }
        
        if self.motion.isDeviceMotionAvailable{
            print("Start Device Motion sensors: interval = \(interval)")
            self.motion.deviceMotionUpdateInterval = interval
            // self.motion.showsDeviceMovementDisplay = true
            // self.motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
            self.motion.startDeviceMotionUpdates()
        }
        
        // Configure a timer to fetch the data.
        if self.timer == nil {
            self.timer = Timer(fire: Date(), interval: interval,
                               repeats: true, block: { (timer) in
                                
                                if let motion = self.motion.deviceMotion {
                                    self.addDeviceMotion(motion)
                                    self.sensorData.deviceMotionData = motion
                                }
                                
                                if let acc = self.motion.accelerometerData {
                                    self.sensorData.accData = acc
                                }
                                
                                self.sensorData.save()
                                
                                self.elapse = self.elapse + 1
                                if (self.elapse > 20 ) {
                                    // TODO: CoreMotion
                                    if (self.deviceMotions.count == 200){
                                        let stateIn = self.result?.stateOut
                                        if let input = self.conv(input:self.deviceMotions, stateIn:stateIn ){
                                            do {
                                                self.result = try self.classifier?.prediction(input: input)
                                                if let r = self.result {
                                                    let maxAcc = self.getMaxConvAcc(self.deviceMotions)
                                                    // print(r.label)
                                                    if let handler = self.classificationResultHandler{
                                                        handler(r, maxAcc)
                                                    }
                                                }
                                            } catch  {
                                                print(error)
                                            }
                                        }
                                    }
                                    self.elapse = 0
                                }
                               })
            // Add the timer to the current run loop.
            RunLoop.current.add(self.timer!, forMode: .default)
        }
        
        if CMAltimeter.isRelativeAltitudeAvailable(){
            altimeter.startRelativeAltitudeUpdates(to: .main) { (altitudeData, error) in
                if let altData = altitudeData{
                    self.sensorData.barometer = altData.pressure.doubleValue
                }
            }
        }
    }
    
    var result:BatSwingClassifierOutput?
    
    func conv(input:[CMDeviceMotion], stateIn:MLMultiArray?)->BatSwingClassifierInput? {
        var rx = [Double]()
        var ry = [Double]()
        var rz = [Double]()
        var ux = [Double]()
        var uy = [Double]()
        var uz = [Double]()
        
        for i in input {
            rx.append(i.rotationRate.x)
            ry.append(i.rotationRate.y)
            rz.append(i.rotationRate.z)
            ux.append(i.userAcceleration.x)
            uy.append(i.userAcceleration.y)
            uz.append(i.userAcceleration.z)
        }
        do {
            let rxm = try MLMultiArray(rx)
            let rym = try MLMultiArray(ry)
            let rzm = try MLMultiArray(rz)
            let uxm = try MLMultiArray(ux)
            let uym = try MLMultiArray(uy)
            let uzm = try MLMultiArray(uz)
            
            let sIn = try MLMultiArray(shape: [400], dataType: .double)
            return BatSwingClassifierInput(rotation_x: rxm,
                                           rotation_y: rym,
                                           rotation_z: rzm,
                                           user_acc_x: uxm,
                                           user_acc_y: uym,
                                           user_acc_z: uzm,
                                           stateIn: sIn)
        } catch {
            
        }
        
        return nil
    }
    
    func getMaxConvAcc(_ acc:[CMDeviceMotion]) -> Double{
        let convAcc = acc.map { motion -> Double in
            let x = motion.userAcceleration.x
            let y = motion.userAcceleration.y
            let z = motion.userAcceleration.z
            let conv = sqrt((x*x) + (y*y) + (z*z))
            return conv
        }
        return convAcc.max() ?? 0
    }
    
    func addDeviceMotion(_ deviceMotion:CMDeviceMotion){
        if (self.deviceMotions.count > 199) {
            self.deviceMotions.remove(at: 0)
        }
        self.deviceMotions.append(deviceMotion)
    }
    
    func stopMotionSensors(){
        if self.motion.isAccelerometerAvailable{
            self.motion.stopAccelerometerUpdates()
            print("Stop Accelerometer sensor")
        }
        
        if self.motion.isDeviceMotionAvailable{
            self.motion.stopDeviceMotionUpdates()
            print("Stop Device Motion sensor")
        }
        
        if let t = self.timer {
            t.invalidate()
            self.timer = nil
        }
    }
    
    func startWorkout() {
        
        // If we have already started the workout, then do nothing.
        if (session != nil) {
            return
        }
        
        // Configure the workout session.
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .other
        workoutConfiguration.locationType = .indoor
        
        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: workoutConfiguration)
            if let uwSession = session {
                uwSession.delegate = self
                uwSession.startActivity(with: Date())
            }
        } catch {
            fatalError("Unable to create the workout session!")
        }
    }
    
    func createHeartRateStreamingQuery(_ workoutStartDate: Date) -> HKQuery? {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate) else { return nil }
        let datePredicate = HKQuery.predicateForSamples(withStart: workoutStartDate, end: nil, options: .strictEndDate )
        //let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates:[datePredicate])
        
        
        let heartRateQuery = HKAnchoredObjectQuery(type: quantityType, predicate: predicate, anchor: nil, limit: Int(HKObjectQueryNoLimit)) { (query, sampleObjects, deletedObjects, newAnchor, error) -> Void in
            //guard let newAnchor = newAnchor else {return}
            //self.anchor = newAnchor
            self.updateHeartRate(sampleObjects)
        }
        
        heartRateQuery.updateHandler = {(query, samples, deleteObjects, newAnchor, error) -> Void in
            //self.anchor = newAnchor!
            self.updateHeartRate(samples)
        }
        return heartRateQuery
    }
    
    func updateHeartRate(_ samples: [HKSample]?) {
        guard let heartRateSamples = samples as? [HKQuantitySample] else {return}
        guard let sample = heartRateSamples.first else{return}
        let hr = sample.quantity.doubleValue(for: self.heartRateUnit)
        // TODO: Heart-Rate
        sensorData.hr = hr
    }
}




extension SensorManager:HKWorkoutSessionDelegate{
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        switch toState {
        case .running:
            workoutDidStart(date)
        case .ended:
            workoutDidEnd(date)
        default:
            print("Unexpected state \(toState)")
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout error")
    }
    
    func workoutDidStart(_ date : Date) {
        if let query = createHeartRateStreamingQuery(date) {
            self.currenQuery = query
            healthStore.execute(query)
        } else {
            // label.setText("cannot start")
        }
    }
    
    func workoutDidEnd(_ date : Date) {
        if let query = self.currenQuery{
            healthStore.stop(query)
            // label.setText("---")
        }
        session = nil
    }
}


public func createFileUrl(fileName:String) -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let docsDirect = paths[0]
    let audioUrl = docsDirect.appendingPathComponent(fileName)
    
    return audioUrl
}

public class SensorData:NSObject{
    
    public var filePath:URL?
    let fileManager = FileManager.init()
    var fileHandle:FileHandle? = nil
    
    public var label = ""
    
    // heart-rate
    public var hr:Double = 0
    
    // barometer
    public var barometer:Double = 0
    
    var isWriteable:Bool = false
    
    var lastUpdate = Date()
    
    public var deviceMotionData:CMDeviceMotion?
    public var accData:CMAccelerometerData?
    
    public init(_ fileUrl:URL? = nil) {
        if fileUrl == nil {
            let timestamp = Int(Date().timeIntervalSince1970)
            filePath = createFileUrl(fileName: "\(timestamp).csv")
        }else{
            filePath = fileUrl
        }
        do {
            let header = "label,timestamp,accx,accy,accz,roll,pitch,yaw,gravity-x,gravity-y,gravity-z,rotation-x,rotation-y,rotation-z,user-acc-x,user-acc-y,user-acc-z,hr,barometer\n"
            try header.write(to: filePath!, atomically: true, encoding: .utf8 )
            
            fileHandle = try FileHandle.init(forWritingTo: self.filePath!)
            // try header.write( to: self.filePath!, atomically: false, encoding: String.Encoding.utf8 )
            isWriteable = true
        } catch {
            print("\(error)")
        }
    }
    
    public func save(){
        if let uwFileHandle = fileHandle {
            if isWriteable {
                if let acc = accData, let deviceMotion = deviceMotionData {
                    uwFileHandle.seekToEndOfFile()
                    let datetime = Date()
                    let now:Double = datetime.timeIntervalSince1970
                    let line = "\(label),\(now),\(acc.acceleration.x),\(acc.acceleration.y),\(acc.acceleration.z),\(deviceMotion.attitude.roll),\(deviceMotion.attitude.pitch),\(deviceMotion.attitude.yaw),\(deviceMotion.gravity.x),\(deviceMotion.gravity.y),\(deviceMotion.gravity.z),\(deviceMotion.rotationRate.x),\(deviceMotion.rotationRate.y),\(deviceMotion.rotationRate.z),\(deviceMotion.userAcceleration.x),\(deviceMotion.userAcceleration.y),\(deviceMotion.userAcceleration.z),\(hr),\(barometer)\n"
                    uwFileHandle.write(line.data(using: String.Encoding.utf8)!)
                    self.lastUpdate = datetime
                }
            }
        }
    }
    
    public func close(){
        if let uwFileHandle = fileHandle {
            if isWriteable{
                uwFileHandle.closeFile()
                isWriteable = false
            }
        }
    }
}
