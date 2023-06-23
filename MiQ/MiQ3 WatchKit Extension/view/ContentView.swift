//
//  ContentView.swift
//  MiQ3 WatchKit Extension
//
//  Created by Yuuki Nishiyama on 2021/08/16.
//

import SwiftUI
import Foundation
import WatchConnectivity

struct ContentView: View{
    
    @Environment(\.managedObjectContext) private var context
    
    @ObservedObject var connector = PhoneConnector()
    
    @Environment(\.presentationMode) var presentation
    
    @State var startTimestamp:Date?
    @State var stopTimestamp:Date?
    @State var currentTime = ""
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let sensorManager = SensorManager()
    
    init() {
        sensorManager.initHealthKit()
    }
    
    @State var isRunning = false
    
    var body: some View {
        ScrollView{
            VStack{
                Toggle(isRunning ? "Monitoring" : "Tap to start", isOn: $isRunning)
                    .onChange(of: isRunning) { value in
                        if (value) {
                            sensorManager.start()
                            sensorManager.classificationResultHandler = { output, value in
                                if (output.label == "swing") {
                                    if (WCSession.default.isReachable){
                                        let session = WCSession.default
                                        session.sendMessage(["message":"A swing event", "value":value]) { reply in
                                            print(reply)
                                        } errorHandler: { error in
                                            print(error)
                                        }
                                    }
                                }
                            }
                            self.startTimestamp = Date()
                            print("start")
                        }else{
                            let now = Date()
                            self.stopTimestamp = now
                            sensorManager.stop()
                            
                            let exercise = EntityExerciseSession(context: self.context)
                            exercise.created_at = now
                            exercise.modified_at = now
                            exercise.end_at = now
                            exercise.start_at = startTimestamp
                            if let url = self.sensorManager.sensorData.filePath {
                                print(url.lastPathComponent)
                                exercise.raw_data = url.lastPathComponent
                            }
                            do {
                                try self.context.save()
                            } catch {
                                print(error.localizedDescription)
                            }
                            print("stop")
                        }
                    }.padding(3)
                Spacer().frame(height: 10)
                if (isRunning) {
                    Text("\(currentTime)").onReceive(timer) { input in
                        if let s = self.startTimestamp {
                            let formatter = DateComponentsFormatter()
                            formatter.allowedUnits = [.day, .hour, .minute, .second]
                            formatter.unitsStyle = .short
                            let diff = s.distance(to:Date())
                            currentTime = formatter.string(from: diff) ?? ""
                        }
                    }.padding(5)
                }else{
                    Text("--")
                }
                Divider()
                NavigationLink("History",
                               destination: HistoryView()
                                .environment(\.managedObjectContext, context)
                ).padding(3)
                Button("Connection Test"){
                    if (WCSession.default.isReachable){
                        let session = WCSession.default
                        session.sendMessage(["message":"A test message from Apple Watch"]) { reply in
                            print(reply)
                        } errorHandler: { error in
                            print(error)
                        }
                    }else{
                        print("not isReachable")
                    }
                }
            }
        }
        //.environment(\.managedObjectContext, context)
    }
}




struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


class PhoneConnector: NSObject, ObservableObject, WCSessionDelegate {
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("activationDidCompleteWith state= \(activationState.rawValue)")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("didReceiveMessage: \(message)")
    }
    
}
