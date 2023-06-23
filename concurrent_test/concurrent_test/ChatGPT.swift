//
//  ChatGPTtest.swift
//  concurrent_test
//
//  Created by sezaki on 2023/06/02.
//

import Foundation
import OpenAISwift
import PDFKit

class ChatGPT{
    private let openAI = OpenAISwift(authToken: "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")
    var chatMessage = [ChatMessage]()
    var allContent = ""
    var pdfContent = ""
    let pdfURL = Bundle.main.url(forResource: "test", withExtension: "pdf")!
//    let textURL = Bundle.main.url(forResource: "text", withExtension: "text")!
    var responseMessage = ""
    
    func extractText(from textURL: URL)  {
        guard let fileURL = Bundle.main.url(forResource: "text", withExtension: "txt"),
              let fileContents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            fatalError("読み込み出来ません")
        }
        pdfContent.append("\(fileContents)\n")
        
//        guard let pdfDoc = PDFDocument(url: pdfURL) else {
//            return
//        }
//
//        for i in 0..<pdfDoc.pageCount {
//            guard let page = pdfDoc.page(at: i) else {
//                continue
//            }
//            guard let pageText = page.string else {
//                continue
//            }
//            pdfContent.append("\(pageText)\n")
//        }
    }
    
    func initializeRole(){
        extractText(from: pdfURL)
        chatMessage = [
            ChatMessage(role: .system, content: "以下の文章はある研究の内容です。この内容について把握してください。"),
            ChatMessage(role: .system, content: pdfContent),
        ]
    }
    
    func chat() async{
        do {
            let result = try await openAI.sendChat(with: chatMessage, model: .chat(.chatgpt))
            let resultContent = result.choices?.first?.message.content ?? ""
            
            responseMessage = resultContent + "\n"
            
//            chatMessage.append(ChatMessage(role: .system, content: resultContent))
            print(resultContent)

        } catch {
            // ...

        }
    }
    
}
