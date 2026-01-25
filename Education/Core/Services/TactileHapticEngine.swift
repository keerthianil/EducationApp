//
//  TactileHapticEngine.swift
//  Education
//
//  Haptic feedback engine for tactile graphics exploration
//  Pattern: Continuous vibration while dragging along lines, pulsing on vertices/landmarks

import SwiftUI
import UIKit

class TactileHapticEngine {
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private var continuousTimer: Timer?
    private var isContinuousActive = false
    private var pulseCount = 0 // Track pulse count for periodic re-preparation
    
    init() {
        // Prepare generators for immediate response
        // Re-prepare frequently to ensure VoiceOver compatibility
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selection.prepare()
    }
    
    // Re-prepare generators (call periodically to ensure VoiceOver compatibility)
    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selection.prepare()
    }
    
    // Single tap / initial touch
    func play(for type: HitType) {
        switch type {
        case .onLine:
            // Initial touch on line - start continuous vibration immediately
            // Use stronger haptics that work with VoiceOver
            continuous()
            // Play subtle sound to confirm touch (even with VoiceOver)
            AudioServicesPlaySystemSound(1104) // Subtle tap sound
            
        case .onVertex:
            // Vertex/intersection - strong pulse (like landmark in Nav_Indoor)
            // Use maximum intensity for VoiceOver compatibility
            heavyImpact.impactOccurred(intensity: 1.0)
            // Play audio "ding" for vertex (like intersection announcement)
            AudioServicesPlaySystemSound(1057) // System sound ID for "ding"
            
        case .onLabel:
            // Label touch - medium feedback with sound
            mediumImpact.impactOccurred(intensity: 0.8)
            AudioServicesPlaySystemSound(1103) // Light tap sound
            
        case .insideShape:
            // Inside polygon - medium feedback with sound
            mediumImpact.impactOccurred(intensity: 0.8)
            AudioServicesPlaySystemSound(1104) // Subtle tap sound
        }
    }
    
    // Continuous vibration while dragging along line (like Nav_Indoor corridors)
    // Uses rapid pulses to simulate continuous vibration
    // Works with VoiceOver by using stronger, more frequent haptics
    func continuous() {
        guard !isContinuousActive else { return }
        isContinuousActive = true
        
        // Stop any existing timer
        continuousTimer?.invalidate()
        
        // Re-prepare to ensure VoiceOver compatibility
        mediumImpact.prepare()
        
        // Start immediately with stronger pulse for VoiceOver compatibility
        // Use higher intensity (0.7) to ensure it's felt even with VoiceOver
        mediumImpact.impactOccurred(intensity: 0.7)
        
        // Reset pulse count
        pulseCount = 0
        
        // Continuous vibration every ~30ms while on line
        // Faster pulses = more continuous feeling (Nav_Indoor pattern)
        // Higher intensity for VoiceOver compatibility
        continuousTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] timer in
            guard let self = self, self.isContinuousActive else {
                timer.invalidate()
                return
            }
            // Medium intensity continuous vibration - feels like constant vibration
            // Intensity 0.7 for stronger feedback that works with VoiceOver
            // Re-prepare every 10 pulses to ensure reliability
            DispatchQueue.main.async {
                self.pulseCount += 1
                if self.pulseCount % 10 == 0 {
                    self.mediumImpact.prepare()
                }
                self.mediumImpact.impactOccurred(intensity: 0.7)
            }
        }
        
        // Ensure timer runs on main run loop for smooth operation
        if let timer = continuousTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // Pulsing feedback (for transitions, vertices)
    func pulse() {
        // Strong pulse for boundary crossing or vertex
        heavyImpact.impactOccurred(intensity: 0.8)
    }
    
    // Stop all haptics
    func stop() {
        isContinuousActive = false
        pulseCount = 0
        continuousTimer?.invalidate()
        continuousTimer = nil
    }
}

import AudioToolbox
