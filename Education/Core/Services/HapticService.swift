//
//  HapticService.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import Foundation
import Combine
import CoreHaptics
import UIKit

/// Haptic feedback service for accessibility cues
final class HapticService: ObservableObject {
    
    // Basic selection feedback
    func tapSelection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    // Success - block finished loading, playback complete
    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    // Error feedback
    func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    // Math content - start (pulse to signal math)
    func mathStart() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
    
    // Math term/variable haptic (brief pulse)
    func mathTerm() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    // Math content - end
    func mathEnd() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    // Section change cue
    func sectionChange() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Page change cue
    func pageChange() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
    
    // Chemistry bond haptic (for future use)
    func chemBond() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}
