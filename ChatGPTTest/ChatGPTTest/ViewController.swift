//
//  ViewController.swift
//  ChatGPTTest
//
//  Created by Zhenbo Wang on 2023/6/4.
//

import UIKit
import OpenAISwift
import PDFKit

class ViewController: UIViewController {

    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var textView: UITextView!
    var chatMessage = [ChatMessage]()
    let openAI = OpenAISwift(authToken: "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")
    
    var allContent = ""
    var pdfText = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        // 从网络下载pdf文件
       //let pdfURL = URL(string: "https://github.com/WJaskon/openhouse/blob/main/lecture1.pdf")!
       //updateContent(sys: "PDFファイルをアップロードしています...")
       //Task {
           //do {
              // let pdfText = try await downloadPDF(from: pdfURL)
              // self.pdfText = pdfText
              // updateContent(sys: "アップロードしました")
          // } catch {
             //  updateContent(sys: "アップロードできません")
              // exit(1)
           //}
      // }

        // 从本地读取pdf文件
          let pdfURL = Bundle.main.url(forResource: "test", withExtension: "pdf")!
        
          guard let pdfText = extractText(from: pdfURL) else {
             updateContent(sys: "アップロードできません")
             exit(1)
         }
         self.pdfText = pdfText
         print("アップロードしました：\n\(pdfText)")
         updateContent(sys: "アップロードしました")
        
        reset()
    }

    
    func reset() {
        chatMessage = [
            ChatMessage(role: .system, content: "５５歳の情報分野の研究者の喋り方で会話してください。"),
            ChatMessage(role: .user, content: pdfText),
        ]
    }
    
    func chat() async {
        
        do {
            let result = try await openAI.sendChat(with: chatMessage, model: .chat(.chatgpt))
            let resultContent = result.choices?.first?.message.content ?? ""
            
            allContent += "Ai:\n"
            allContent += resultContent
            allContent += "\n"
            textView.text = allContent
            
            chatMessage.append(ChatMessage(role: .system, content: resultContent))
            print(resultContent)
            
        } catch {
            // ...
            
        }
    }
    
    @IBAction func send(_ sender: Any) {
        
        let inputText = inputTextField.text ?? ""
        
        if inputText == "終わり" {
            reset()
            allContent += "Sys:\n"
            allContent += "現在のセッションは終了し、新しいセッションを開始します。"
            allContent += "\n"
            textView.text = allContent
        } else {
            allContent += "Me:\n"
            allContent += inputText
            allContent += "\n"
            textView.text = allContent
            
            chatMessage.append(ChatMessage(role: .user, content: inputText))
            
            Task {
                await chat()
            }
        }
        
        inputTextField.text = ""
    }

    // 从url下载pdf文件，并解析出文本
    func downloadPDF(from url: URL) async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: url)
        let pdfDoc = PDFDocument(data: data)
        var text = ""
        for i in 0..<pdfDoc!.pageCount {
            guard let page = pdfDoc?.page(at: i) else {
                continue
            }
            guard let pageText = page.string else {
                continue
            }
            text.append("\(pageText)\n")
        }
        return text
    }
    
    func extractText(from pdfURL: URL) -> String? {
        guard let pdfDoc = PDFDocument(url: pdfURL) else {
            return nil
        }
        
        var text = ""
        for i in 0..<pdfDoc.pageCount {
            guard let page = pdfDoc.page(at: i) else {
                continue
            }
            guard let pageText = page.string else {
                continue
            }
            text.append("\(pageText)\n")
        }
        
        return text
    }

    func updateContent(sys: String) {
        allContent += "Sys:\n"
        allContent += sys
        allContent += "\n"
        textView.text = allContent
    }
}

