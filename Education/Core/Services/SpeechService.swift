//
//  SpeechService.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import Foundation
import Combine
import AVFoundation
import UIKit

/// Shared speech engine used for continuous read-aloud.
/// We also listen for app background events so audio always stops
/// when the user closes the app or switches away.
final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()

    @Published var isSpeaking = false

    override init() {
        super.init()
        synth.delegate = self

        // Stop any reading when the app goes to background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Speak a block of text using the system voice.
    func speak(_ text: String, rate: Float = 0.5) {
        guard !text.isEmpty else { return }

        if synth.isSpeaking {
            synth.stopSpeaking(at: .immediate)
        }

        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utt.rate = min(max(rate, 0.4), 0.6)

        synth.speak(utt)
    }

    /// Stop speaking. Used when the user closes the document or app.
    func stop(immediate: Bool) {
        synth.stopSpeaking(at: immediate ? .immediate : .word)
        isSpeaking = false
    }

    // MARK: - App lifecycle

    /// Called when the app goes to background or loses focus.
    @objc private func handleAppBackground(_ notification: Notification) {
        stop(immediate: true)
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
