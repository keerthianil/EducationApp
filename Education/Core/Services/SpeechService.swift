//
//  SpeechService.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import Foundation
import Combine
import AVFoundation

/// Wrapper around AVSpeechSynthesizer so any view can trigger TTS.
/// This is used both for continuous reading and for short math descriptions.
final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    @Published var isSpeaking = false

    override init() {
        super.init()
        synth.delegate = self
    }

    /// Speak the given text using the current system voice.
    /// If something is already speaking, it is stopped immediately
    /// to avoid overlapping audio or crashes.
    func speak(_ text: String, rate: Float = 0.5) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }

        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utt.rate = min(max(rate, 0.4), 0.6)
        synth.speak(utt)
    }

    /// Stop speaking, either immediately or at the end of the current word.
    func stop(immediate: Bool) {
        synth.stopSpeaking(at: immediate ? .immediate : .word)
        isSpeaking = false
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart utt: AVSpeechUtterance) {
        isSpeaking = true
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utt: AVSpeechUtterance) {
        isSpeaking = false
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utt: AVSpeechUtterance) {
        isSpeaking = false
    }
}
