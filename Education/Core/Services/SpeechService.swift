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

/// Shared speech engine used for block-level read-aloud.
/// Tracks speaking state so UI can show play/pause correctly.
final class SpeechService: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()

    @Published var isSpeaking = false
    @Published var isPaused = false

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
    
    /// Pause current speech
    func pause() {
        if synth.isSpeaking && !synth.isPaused {
            synth.pauseSpeaking(at: .word)
            isPaused = true
        }
    }
    
    /// Resume paused speech
    func resume() {
        if synth.isPaused {
            synth.continueSpeaking()
            isPaused = false
        }
    }

    /// Stop speaking. Used when the user closes the document or app.
    func stop(immediate: Bool) {
        synth.stopSpeaking(at: immediate ? .immediate : .word)
        isSpeaking = false
        isPaused = false
    }

    // MARK: - App lifecycle

    @objc private func handleAppBackground(_ notification: Notification) {
        stop(immediate: true)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart utt: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
            self.isPaused = false
        }
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish utt: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
        }
    }

    func speechSynthesizer(_ s: AVSpeechSynthesizer, didCancel utt: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.isPaused = false
        }
    }
    
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didPause utt: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPaused = true
        }
    }
    
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didContinue utt: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isPaused = false
        }
    }
}
