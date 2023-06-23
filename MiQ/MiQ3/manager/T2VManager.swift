//
//  TextToSpeechManager.swift
//  MiQ
//
//  Created by Yuuki Nishiyama on 2021/05/15.
//

import UIKit
import Speech

class T2VManager: NSObject {
    
    // text to speech
    public let talker = AVSpeechSynthesizer()
    public var delegate:AVSpeechSynthesizerDelegate?
    
    var callback:(()->Void)?
    
    override init() {
        super.init()
        prepareAllSounds()
    }
    
    func speech(string:String, language:String = "en-US", callback:@escaping (()->Void)){
        self.callback = callback
        
        let utterance = AVSpeechUtterance(string: string)
        utterance.voice = AVSpeechSynthesisVoice(language: language)

        talker.delegate = delegate
        if (talker.delegate == nil) {
            talker.delegate = self
        }
        talker.speak(utterance)
    }
    
    
    ///////////////////////////
    
    var donePlayer:  AVAudioPlayer?
    var endPlayer:   AVAudioPlayer?
    var startPlayer: AVAudioPlayer?
    
    enum SoundName:String {
        case done  = "siri_done"
        case end   = "siri_end"
        case start = "siri_start"
    }
    
    
    /// **must** define instance variable outside, because .play() will deallocate AVAudioPlayer
    /// immediately and you won't hear a thing
    
    func prepareAllSounds(){
        for name in [SoundName.done, SoundName.end, SoundName.start] {
            if let url = Bundle.main.url(forResource: name.rawValue, withExtension: "mov") {
                do {
                    /// change fileTypeHint according to the type of your audio file (you can omit this)
                    let player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
                    player.prepareToPlay()
                    // player.play()
  
                    // no need for prepareToPlay because prepareToPlay is happen automatically when calling play()
                    switch name {
                    case .done:
                        donePlayer = player
                        break
                    case .end:
                        endPlayer = player
                        break
                    case .start:
                        startPlayer = player
                        break
                    }
                } catch let error as NSError {
                    print("error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func play(sound:SoundName) {
        for player in [donePlayer, endPlayer, startPlayer] {
            if let channels = player?.channelAssignments{
                for c in channels {
                    print(c)
                }
            }
        }
        switch sound {
        case .done:
            donePlayer?.play()
            break
        case .end:
            endPlayer?.play()
            break
        case .start:
            startPlayer?.play()
            break
        }
    }
    
}

extension T2VManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance){
        print(utterance)
        if let callback = self.callback {
            callback()
        }
    }
}
