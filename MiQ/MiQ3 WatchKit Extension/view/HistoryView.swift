//
//  HistoryView.swift
//  MiQ3 WatchKit Extension
//
//  Created by Yuuki Nishiyama on 2021/08/22.
//

import SwiftUI
import CoreData
import AVFoundation
import WatchConnectivity

struct HistoryView: View {
    
    @Environment(\.presentationMode) var presentation
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        entity: EntityExerciseSession.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \EntityExerciseSession.created_at, ascending: false)],
        predicate: nil,
        animation: .default
    ) private var exercises: FetchedResults<EntityExerciseSession>
    
    
    var inputFormatter = DateFormatter()
    var timeFormatter = DateComponentsFormatter()

    
    init() {
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        timeFormatter.allowedUnits = [.day, .hour, .minute, .second]
        timeFormatter.unitsStyle = .short
    }
    
    var body: some View {
        List{
            ForEach(exercises, id:\.self){ exercise in
                let start = exercise.start_at ?? Date()
                let end = exercise.end_at ?? Date()
                let duration = start.distance(to:end)
                HStack {
                    VStack(alignment: .leading) {
                        Text(inputFormatter.string(from: start))
                            .font(.footnote).foregroundColor(.gray)
                        Text(self.timeFormatter.string(from: duration) ?? "")
                    }
                    Spacer()
                    NavigationLink(
                        destination:LogView(exercise)
                            .environment(\.managedObjectContext, context)
                    ){}.frame(width: 20)
                }
            }
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}

struct LogView: View{
    
    @Environment(\.presentationMode) var presentation
    @Environment(\.managedObjectContext) private var context
    let exercise:EntityExerciseSession
    
    let start:String
    let end:String
    let date:String
    let duration:String
    
    
    @State var showAlert = false
    @State var showErrorMsg = false
    @State var errorMsg = ""
    
    init(_ exercise:EntityExerciseSession){

        let startDate = exercise.start_at ?? Date()
        let endDate = exercise.end_at ?? Date()

        self.exercise = exercise

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        self.start = timeFormatter.string(from: startDate)
        self.end = timeFormatter.string(from: endDate)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        self.date = dateFormatter.string(from: startDate)
        
        let durationFormatter = DateComponentsFormatter()
        durationFormatter.allowedUnits = [.day, .hour, .minute, .second]
        durationFormatter.unitsStyle = .short
        self.duration = durationFormatter.string(from: startDate.distance(to:endDate)) ?? ""
    }
    
    var body: some View{
        VStack {
            Spacer()
            Text(self.exercise.raw_data ?? "").font(.caption)
            Spacer()
            Text("日付:\(self.date)").font(.footnote).foregroundColor(.gray)
            Text("開始:\(self.start)").font(.footnote).foregroundColor(.gray)
            Text("終了:\(self.end)").font(.footnote).foregroundColor(.gray)
            Spacer()
            Text(self.duration).bold()
            Spacer()
            HStack{
                Button("削除"){
                    self.showAlert = true
                }
                .buttonStyle(BorderedButtonStyle(tint: .red))
                .actionSheet(isPresented: $showAlert) {
                    ActionSheet(title: Text("本当に削除しますか？"),
                                buttons: [
                                    .destructive(Text("はい"), action:{
                                        context.delete(self.exercise)
                                        self.presentation.wrappedValue.dismiss()
                                        self.showAlert = false
                                    }),
                                    .default(Text("いいえ"), action: {
                                        self.showAlert = false
                                    })
                                ]
                    )
                }
                Button("転送"){
                    if let fileName = self.exercise.raw_data {
                        let url = createFileUrl(fileName: fileName)
                        if (WCSession.default.isReachable){
                            let session = WCSession.default
                            session.transferFile(url, metadata: ["filename":fileName])
                            self.showErrorMsg = true
                            self.errorMsg = "ファイル転送を開始します。"
                        }else{
                            print("not isReachable")
                        }
                    }
                }.buttonStyle(BorderedButtonStyle(tint: .blue))
                .disabled(!WCSession.default.isReachable)
                .actionSheet(isPresented: $showErrorMsg, content: {
                    ActionSheet(title: Text(self.errorMsg),
                                buttons: [
                                    .default(Text("閉じる"), action: {
                                        self.showErrorMsg = false
                                    })
                                ]
                    )
                })
            }
        }
    }
    
    public func createFileUrl(fileName:String) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docsDirect = paths[0]
        let audioUrl = docsDirect.appendingPathComponent(fileName)
        
        return audioUrl
    }
}
