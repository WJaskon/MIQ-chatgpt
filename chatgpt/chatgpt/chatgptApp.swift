//
//  chatgptApp.swift
//  chatgpt
//
//  Created by Wjaskon on 2023/06/03.
//

import SwiftUI

@main
struct chatgptApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: chatgptDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
