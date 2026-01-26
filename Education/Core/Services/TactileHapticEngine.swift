//
//  TactileHapticEngine.swift
//  Education
//
//  Haptic feedback engine for tactile graphics exploration
//  Pattern: Continuous vibration while dragging along lines, pulsing on vertices/landmarks

import SwiftUI
import UIKit
import AudioToolbox
import CoreHaptics

class TactileHapticEngine {
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    private var continuousTimer: Timer?
    private var isContinuousActive = false
    private var pulseCount = 0 // Track pulse count for periodic re-preparation
    
    // CoreHaptics engine for VoiceOver compatibility
    private var hapticEngine: CHHapticEngine?
    private var isHapticEngineReady = false
    
    init() {
        // Prepare generators for immediate response
        prepare()
        
        // Initialize CoreHaptics engine for VoiceOver
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                // Use playsHapticsOnly to avoid conflicts with AVAudioSession
                hapticEngine = try CHHapticEngine()
                hapticEngine?.stoppedHandler = { [weak self] reason in
                    self?.isHapticEngineReady = false
                    #if DEBUG
                    print("[Haptics] Engine stopped: \(reason.rawValue)")
                    #endif
                    if reason == .audioSessionInterrupt {
                        // Try to restart
                        self?.startHapticEngine()
                    }
                }
                hapticEngine?.resetHandler = { [weak self] in
                    self?.isHapticEngineReady = false
                    #if DEBUG
                    print("[Haptics] Engine reset")
                    #endif
                    self?.startHapticEngine()
                }
                startHapticEngine()
            } catch {
                #if DEBUG
                print("[Haptics] Failed to create CoreHaptics engine: \(error)")
                #endif
            }
        } else {
            #if DEBUG
            print("[Haptics] Device does not support haptics")
            #endif
        }
    }
    
    private func startHapticEngine() {
        guard let engine = hapticEngine else { return }
        do {
            try engine.start()
            isHapticEngineReady = true
        } catch {
            #if DEBUG
            print("[Haptics] Failed to start CoreHaptics engine: \(error)")
            #endif
            isHapticEngineReady = false
        }
    }
    
    // Re-prepare generators (call periodically to ensure VoiceOver compatibility)
    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selection.prepare()
        notification.prepare()
        
        // Ensure CoreHaptics engine is ready
        if !isHapticEngineReady, let engine = hapticEngine {
            startHapticEngine()
        }
    }
    
    // Create fresh generator for VoiceOver compatibility
    private func createFreshGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        return generator
    }
    
    // Use CoreHaptics for VoiceOver - more reliable
    private func playCoreHaptic(intensity: Float, sharpness: Float = 0.5) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        
        // Try CoreHaptics first
        if let engine = hapticEngine, isHapticEngineReady {
            do {
                let hapticIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
                let hapticSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
                
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [hapticIntensity, hapticSharpness],
                    relativeTime: 0
                )
                
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: 0)
                #if DEBUG
                print("[Haptics] CoreHaptics played: intensity=\(intensity)")
                #endif
                return
            } catch {
                #if DEBUG
                print("[Haptics] CoreHaptics play failed: \(error)")
                #endif
            }
        }
        
        // Fallback 1: Use AudioServicesPlaySystemSound with haptic patterns
        // System sound IDs that include haptics: 1519 (peek), 1520 (pop), 1521 (nope)
        AudioServicesPlaySystemSound(1519) // Peek haptic
        
        // Fallback 2: UIImpactFeedbackGenerator
        let generator = createFreshGenerator(style: .heavy)
        generator.impactOccurred(intensity: CGFloat(intensity))
    }
    
    // Continuous CoreHaptics pattern
    private func playContinuousCoreHaptic(intensity: Float, duration: TimeInterval) {
        guard UIAccessibility.isVoiceOverRunning,
              let engine = hapticEngine,
              isHapticEngineReady else { return }
        
        do {
            let hapticIntensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
            let hapticSharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [hapticIntensity, hapticSharpness],
                relativeTime: 0,
                duration: duration
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            #if DEBUG
            print("[Haptics] CoreHaptics continuous play failed: \(error)")
            #endif
        }
    }
    
    // Single tap / initial touch
    func play(for type: HitType) {
        let isVoiceOverOn = UIAccessibility.isVoiceOverRunning
        
        #if DEBUG
        print("[Haptics] play() called for type: \(type), VoiceOver: \(isVoiceOverOn)")
        #endif
        
        // For VoiceOver, use multiple methods simultaneously for maximum reliability
        if isVoiceOverOn {
            switch type {
            case .onLine:
                // Initial touch on line - start continuous vibration immediately
                continuous()
                
            case .onVertex:
                // Vertex/intersection - use ALL methods simultaneously
                #if DEBUG
                print("[Haptics] Playing vertex haptic with VoiceOver")
                #endif
                
                // Method 1: CoreHaptics
                playCoreHaptic(intensity: 1.0, sharpness: 0.9)
                
                // Method 2: Multiple UIImpactFeedbackGenerator instances
                let heavy1 = createFreshGenerator(style: .heavy)
                heavy1.impactOccurred(intensity: 1.0)
                
                // Method 3: Notification feedback
                notification.prepare()
                notification.notificationOccurred(.success)
                
                // Method 4: System sound with haptics
                AudioServicesPlaySystemSound(1519) // Peek
                AudioServicesPlaySystemSound(1520) // Pop
                
                // Method 5: Ding sound
                AudioServicesPlaySystemSound(1057)
                
                // Method 6: Another heavy impact after short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let heavy2 = self.createFreshGenerator(style: .heavy)
                    heavy2.impactOccurred(intensity: 1.0)
                }
                
            case .onLabel:
                // Label touch - use multiple methods
                playCoreHaptic(intensity: 0.8, sharpness: 0.5)
                let freshMedium = createFreshGenerator(style: .medium)
                freshMedium.impactOccurred(intensity: 1.0)
                AudioServicesPlaySystemSound(1519)
                
            case .insideShape:
                // Inside polygon - use multiple methods
                playCoreHaptic(intensity: 0.7, sharpness: 0.3)
                let freshMedium = createFreshGenerator(style: .medium)
                freshMedium.impactOccurred(intensity: 0.9)
            }
        } else {
            // Normal mode - use cached generators
            switch type {
            case .onLine:
                continuous()
                AudioServicesPlaySystemSound(1104)
                
            case .onVertex:
                heavyImpact.impactOccurred(intensity: 1.0)
                AudioServicesPlaySystemSound(1057)
                
            case .onLabel:
                mediumImpact.impactOccurred(intensity: 0.8)
                AudioServicesPlaySystemSound(1103)
                
            case .insideShape:
                mediumImpact.impactOccurred(intensity: 0.8)
                AudioServicesPlaySystemSound(1104)
            }
        }
    }
    
    /// Play haptic with intensity based on progress (0.0 to 1.0)
    func playWithIntensity(_ intensity: CGFloat, for type: HitType) {
        let clampedIntensity = max(0.3, min(1.0, intensity))
        
        switch type {
        case .onLine:
            mediumImpact.impactOccurred(intensity: clampedIntensity)
        case .onVertex:
            heavyImpact.impactOccurred(intensity: 1.0) // Always strong for vertices
        case .onLabel:
            mediumImpact.impactOccurred(intensity: clampedIntensity)
        case .insideShape:
            lightImpact.impactOccurred(intensity: clampedIntensity)
        }
    }
    
    // Continuous vibration while dragging along line
    // Uses rapid pulses to simulate continuous vibration
    // Works with VoiceOver by using CoreHaptics
    func continuous() {
        guard !isContinuousActive else { return }
        isContinuousActive = true
        
        let isVoiceOverOn = UIAccessibility.isVoiceOverRunning
        
        // Stop any existing timer
        continuousTimer?.invalidate()
        
        // Start immediately
        if isVoiceOverOn {
            // For VoiceOver, use CoreHaptics continuous pattern
            playContinuousCoreHaptic(intensity: 0.8, duration: 0.1)
            // Also use fresh generator as backup
            let freshMedium = createFreshGenerator(style: .medium)
            freshMedium.impactOccurred(intensity: 0.9)
        } else {
            mediumImpact.prepare()
            mediumImpact.impactOccurred(intensity: 0.7)
        }
        
        // Reset pulse count
        pulseCount = 0
        
        // Continuous vibration - faster and stronger with VoiceOver
        let interval: TimeInterval = isVoiceOverOn ? 0.05 : 0.03
        let intensity: CGFloat = isVoiceOverOn ? 0.9 : 0.7
        
        continuousTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self, self.isContinuousActive else {
                timer.invalidate()
                return
            }
            
            DispatchQueue.main.async {
                self.pulseCount += 1
                
                if isVoiceOverOn {
                    // Use CoreHaptics for continuous feedback
                    if self.pulseCount % 2 == 0 {
                        self.playCoreHaptic(intensity: 0.7, sharpness: 0.3)
                    }
                    // Also use fresh generator as backup
                    let freshMedium = self.createFreshGenerator(style: .medium)
                    freshMedium.impactOccurred(intensity: intensity)
                } else {
                    // Re-prepare periodically for normal mode
                    if self.pulseCount % 10 == 0 {
                        self.mediumImpact.prepare()
                    }
                    self.mediumImpact.impactOccurred(intensity: intensity)
                }
            }
        }
        
        // Ensure timer runs on main run loop for smooth operation
        if let timer = continuousTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    // Pulsing feedback (for transitions, vertices)
    func pulse() {
        let isVoiceOverOn = UIAccessibility.isVoiceOverRunning
        
        if isVoiceOverOn {
            // Use CoreHaptics for reliable feedback with VoiceOver
            playCoreHaptic(intensity: 1.0, sharpness: 0.9)
            // Also use fresh generator as backup
            let freshHeavy = createFreshGenerator(style: .heavy)
            freshHeavy.impactOccurred(intensity: 1.0)
        } else {
            heavyImpact.impactOccurred(intensity: 0.8)
        }
    }
    
    // Stop all haptics
    func stop() {
        isContinuousActive = false
        pulseCount = 0
        continuousTimer?.invalidate()
        continuousTimer = nil
    }
}