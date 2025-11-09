//
//  SpeechService.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//
import Foundation
import Foundation
import Combine
import AVFoundation
import UIKit

final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    @Published var isSpeaking = false

    override init() {
        super.init()
        synth.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
    }

    @objc private func voChanged() {
        if UIAccessibility.isVoiceOverRunning {
            stop(immediate: true)
        }
    }

    /// Speak text. If VoiceOver is on, let VO handle announcements.
    func speak(_ text: String, rate: Float = 0.5) {
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: text)
            return
        }
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utt.rate = min(max(rate, 0.4), 0.6)
        synth.speak(utt)
    }

    func stop(immediate: Bool = true) {
        if UIAccessibility.isVoiceOverRunning { return }
        synth.stopSpeaking(at: immediate ? .immediate : .word)
    }

    // Delegate
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) { isSpeaking = true }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { isSpeaking = false }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { isSpeaking = false }
}
