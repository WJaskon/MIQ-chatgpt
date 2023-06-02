//
//  conversation.swift
//  chatgppt
//
//  Created by Wjaskon on 2023/06/03.
//

import SwiftUI
import PDFKit

struct ContentView: View {
    @State private var uploadSuccess = false
    @State private var pdfText = ""
    
    var body: some View {
        VStack {
            if uploadSuccess {
                Text(pdfText)
                    .padding()
            } else {
                Text("无法读取")
                    .padding()
            }
            
            Button("上传 PDF") {
                uploadPDF()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
    }
    
    func uploadPDF() {
        // 示例使用，替换为你的 PDF 文件的 GitHub RAW URL
        let pdfURL = URL(string: "https://github.com/sezakilab/open-house-2023-demo/blob/4adc43ffddffcae19a8e9a0b8d98961b0b17cac3/chatgpt/lecture1.pdf")!

        downloadPDF(from: pdfURL) { pdfDocument in
            DispatchQueue.main.async {
                if let pdfDocument = pdfDocument {
                    var text = ""
                    for pageIndex in 0..<pdfDocument.pageCount {
                        if let page = pdfDocument.page(at: pageIndex) {
                            if let pageText = page.string {
                                text += pageText
                            }
                        }
                    }
                    self.pdfText = text
                    self.uploadSuccess = true
                } else {
                    self.uploadSuccess = false
                }
            }
        }
    }

    func downloadPDF(from url: URL, completion: @escaping (PDFDocument?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            let pdfDocument = PDFDocument(data: data)
            completion(pdfDocument)
        }
        task.resume()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
