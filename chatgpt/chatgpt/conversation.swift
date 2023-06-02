//
//  conversation.swift
//  chatgpt
//
//  Created by Wjaskon on 2023/06/03.
//

import Foundation
import UIKit
import PDFKit

class ViewController: UIViewController {
    
    @IBOutlet weak var pdfView: PDFView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let documentURL = Bundle.main.url(forResource: "sample01", withExtension: "pdf") {
            if let document = PDFDocument(url: documentURL) {
                pdfView.document = document
            }
        }
    }
}
