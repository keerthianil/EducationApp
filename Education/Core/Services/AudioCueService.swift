//
//  AudioCueService.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import Foundation
import Combine

final class AudioCueService: ObservableObject {
    enum Cue { case navForward, navBack, select, alert }

    func play(_ cue: Cue) {
        // Stub for earcons; pair with HapticService so feedback is still perceivable.
    }
}
