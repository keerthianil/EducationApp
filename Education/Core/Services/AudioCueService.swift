//
//  AudioCueService.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import Foundation
import Combine
import AVFoundation
import AudioToolbox

final class AudioCueService: ObservableObject {
    enum Cue { case navForward, navBack, select, alert, vertexDing }
    
    private var audioPlayer: AVAudioPlayer?

    func play(_ cue: Cue) {
        // Play system sound for vertex ding
        if cue == .vertexDing {
            // Use system sound for ding
            AudioServicesPlaySystemSound(1057) // System sound: "ding"
        } else {
            // Stub for other earcons; pair with HapticService so feedback is still perceivable.
        }
    }
}
