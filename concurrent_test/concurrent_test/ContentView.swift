//
//  ContentView.swift
//  concurrent_test
//
//  Created by sutatoruta on 2023/05/30.
//

import SwiftUI
import Speech
import CoreMotion
import OpenAISwift


struct ContentView: View {
    @State private var isRunning = false
    @State private var isSensing = false
    @State private var transcription = "transcription"
    @State private var lastTranscription = ""
    @State private var yourTalking = false
    @State private var motion_state = "motion_state"
    @State private var speaker_state = "speaker_state"
    @State private var timer : Timer?
    @State private var response = ""
    private let manager = CMHeadphoneMotionManager()
    private let chatGPT = ChatGPT()
    private let recognitionService = RecognitionService()
    
    init(){
        chatGPT.initializeRole()
    }
    
    private let talker = AVSpeechSynthesizer()
    var body: some View {
        VStack {
            Toggle(isRunning ? "Dictating" : "Tap to start dictation", isOn: $isRunning)
                .onChange(of: isRunning) { value in
                    if (value){
                        recognitionService.startRecognition()
                        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {_ in
                            transcription = recognitionService.bestTranscription
                            yourTalking = recognitionService.yourTalking
                            if(transcription != lastTranscription){
                                lastTranscription = transcription
                                if(!yourTalking){
                                    chatGPT.chatMessage.append(ChatMessage(role: .user, content: transcription))
                                }
                                else{
                                    chatGPT.chatMessage.append(ChatMessage(role: .assistant, content: transcription))
                                }
                            }
                        }
                    } else {
                        recognitionService.stopRecognition()
                        timer?.invalidate()
                    }
                }
            Text(transcription)
                .font(.system(size: 20))
            Toggle(isSensing ? "Sensing" : "Tap to start sensing", isOn: $isSensing)
                .onChange(of: isSensing) { value in
                    if (value){
                        var chatting = false
                        recognitionService.startMotionRecognition()
                        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) {_ in
                            if(!chatting){
                                motion_state = recognitionService.motion_state
                                speaker_state = recognitionService.speaker_state
                                if(motion_state == "heavenward"){
                                    chatting = true
                                    chatGPT.chatMessage.append(ChatMessage(role: .system, content: "この質問に答えてください"))
                                    Task{
                                        await chatGPT.chat()
                                        response = chatGPT.responseMessage
                                        chatGPT.chatMessage.append(ChatMessage(role: .assistant, content: response))
                                        let utterance = AVSpeechUtterance(string: response)
                                        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
                                        talker.speak(utterance)
                                        chatting = false
                                    }
                                    
                                }else if(motion_state == "unazuku"){
                                    chatting = true
                                    chatGPT.chatMessage.append(ChatMessage(role: .system, content: "今の質問を要約してください"))
                                    Task{
                                        await self.chatGPT.chat()
                                        response = chatGPT.responseMessage
                                        chatGPT.chatMessage.append(ChatMessage(role: .assistant, content: response))
                                        let utterance = AVSpeechUtterance(string: response)
                                        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
                                        talker.speak(utterance)
                                        chatting = false
                                    }
                                }
                            }
                            
                        }
                    } else {
                        recognitionService.stopMotionRecognition()
                        timer?.invalidate()
                        motion_state = "motion_state"
                        speaker_state = "speaker_state"
                    }
                }
            Text(motion_state)
                .font(.system(size: 20))
            Text(speaker_state)
                .font(.system(size: 20))
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
