//
//  ContentView.swift
//  chatgpt
//
//  Created by Wjaskon on 2023/06/03.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: chatgptDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(chatgptDocument()))
    }
}
