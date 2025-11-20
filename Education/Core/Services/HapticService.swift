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

final class HapticService: ObservableObject {
    // Use UIFeedbackGenerator so Simulator also gives some response.
    func tapSelection() { UISelectionFeedbackGenerator().selectionChanged() }
    func success()      { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    func error()        { UINotificationFeedbackGenerator().notificationOccurred(.error) }

    // Simple math/chem cues
    func mathStart() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    func mathTerm()  { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    func mathEnd()   { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    func chemBond()  { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
}
