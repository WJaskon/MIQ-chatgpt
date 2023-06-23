import SwiftUI
import CoreMotion

struct ContentView: View {
    var manager: CMHeadphoneMotionManager?
//    private let manager = MotionManager()
    private let writer = MotionWriter()
//    private let classfier = MotionClassifier()
    private let classfier = TalkingClassifier()
    @State var data: CMDeviceMotion?
    @State var timer :Timer?
    @State var counter = 1
    @State var state = ""
    @State var startDate = Date()
    @State var stopDate = Date()
    
    init() {
        manager = CMHeadphoneMotionManager()
    }
    
    var body: some View {
        VStack{
            Text(state)
                .font(.system(size: 20))
            Button {
                
                //show motion data
//                                manager.startUpdate{ data in
//                                    self.data = data
//                                }
                
                //save motion data csv
//                writer.startWrite()
//                timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) {_ in
//                    writer.stopWrite()
//                    counter == 100 ? timer?.invalidate() : writer.startWrite()
//                    counter += 1
//                }
            
                //classfy motion data
                guard let manager = manager else {
                    return
                }
                startDate = Date()
                if !manager.isDeviceMotionAvailable{
                    print("current device does not supports the headphone motion manager.")
                }
                
                manager.startDeviceMotionUpdates(to: OperationQueue.main) { data, error in
                    if error == nil{
                        guard let new_data = data else {return}
                        self.classfier.process(deviceMotion: new_data)
                        //classify in realtime
//                        if classfier.results[0].0 == "neutral"{
//                            state = "not talking"
//                        }else{
//                            state = "talking"
//                        }
                    } else {print(error)}
                }
            } label: {
                Text("Start")
                    .frame(width: 300, height: 44)
                    .background(.blue)
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .cornerRadius(25)
            }
            Button {
                //show motion data
//                manager.stopUpdate()
                
                //save motion data csv
//                writer.stopWrite()
//                counter = 0
                
                //classify motion data
                manager?.stopDeviceMotionUpdates()
                stopDate = Date()
                if classfier.isTalking(startDate: startDate, stopDate: stopDate){
                    state = "you talked"
                }else{
                    state = "not talked"
                }
            } label: {
                Text("Stop")
                    .frame(width: 300, height: 44)
                    .background(.red)
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .cornerRadius(25)
            }
        }
        
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

