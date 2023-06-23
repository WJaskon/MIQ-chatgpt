//
//  MiQ3App.swift
//  MiQ3 WatchKit Extension
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
        WCManager.shared.activate()
    }
    
    @SceneBuilder var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView().environment(\.managedObjectContext, persistenceController.container.viewContext)
            }.onChange(of: scenePhase) { _ in
                persistenceController.save()
            }
        }
        
        WKNotificationScene(controller: NotificationController.self, category: "myCategory")
    }
}

class WCManager: NSObject, WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        print(#function)
        print(activationState)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print(#function)
    }

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        print(#function)
    }

    static var shared = WCManager()

    func activate() {
        // Watch Connectivity
        if (WCSession.isSupported()) {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        } else {
            print("WC is NOT Supported")
        }
    }
}
