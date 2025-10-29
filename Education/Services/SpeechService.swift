//
//  SpeechService.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//
import Foundation
import Combine
import AVFoundation

final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    @Published var isSpeaking = false

    override init() {
        super.init()
        synth.delegate = self
    }

    func speak(_ text: String, rate: Float = 0.5) {
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utt.rate = min(max(rate, 0.4), 0.6)
        synth.speak(utt)
    }
}
