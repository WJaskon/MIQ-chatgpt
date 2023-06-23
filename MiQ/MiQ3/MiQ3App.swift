//
//  MiQ3App.swift
//  MiQ3
//
//  Created by Yuuki Nishiyama on 2021/08/16.
//

import SwiftUI
import WatchConnectivity

@main
struct MiQ3App: App {
    let persistenceController = PersistenceController.shared
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView().environment(\.managedObjectContext, persistenceController.container.viewContext)
        }.onChange(of: scenePhase) { _ in
            persistenceController.save()
        }
    }
}

