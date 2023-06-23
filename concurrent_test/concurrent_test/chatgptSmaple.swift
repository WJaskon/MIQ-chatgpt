//import Foundation
//import OpenAISwift
////import Docx
//
//class ChatGPT{
//    func extractText(from filePath: String) -> String {
//        guard let doc = try? DocxFile(path: filePath) else {
//            return ""
//        }
//
//        var text = ""
//        for paragraph in doc.paragraphs {
//            text += paragraph.text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
//        }
//
//        return text
//    }
//
//    let desktopPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path
//    let filePath = desktopPath.appending("/lecture1.docx")
//
//    if FileManager.default.fileExists(atPath: filePath) {
//        print("Wordのアップロードが成功しました！")
//    } else {
//        print("Wordのアップロードに失敗しました。ファイルパスが正しいかどうかを確認してください。")
//    }
//
//    let wordText = extractText(from: filePath)
//
//    OpenAI.configure(token: "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")
//
//    var messages: [OpenAI.ChatCompletionMessage] = [
//        .init(role: .system, content: "５５歳の情報分野の研究者の喋り方で会話してください。"),
//        .init(role: .user, content: wordText)
//    ]
//
//    while true {
//        if let userInput = readLine() {
//            messages.append(.init(role: .user, content: userInput))
//
//            let response = try? OpenAI.ChatCompletion.create(
//                model: .gpt_3_5_turbo,
//                messages: messages,
//                temperature: 0.8,
//                maxTokens: 1024,
//                n: 1,
//                stop: nil,
//                timeout: 20
//            )
//
//            guard let modelResponse = response?.choices.first?.message.content else {
//                print("エラー：応答を取得できませんでした。")
//                break
//            }
//
//            print("ChatGPT: \(modelResponse)")
//
//            if userInput.contains("終わり") {
//                break
//            }
//
//            messages.append(.init(role: .system, content: modelResponse))
//        }
//    }
//
//    print("終わり")
//
//}
//
