//
//  EducationApp.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import SwiftUI
import Combine

@main
struct EducationApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var speech = SpeechService()
    @StateObject private var haptics = HapticService()
    @StateObject private var mathSpeech = MathSpeechService()
    @StateObject private var audioCue = AudioCueService()

    var body: some Scene {
        WindowGroup {
            RootFlow()
                .environmentObject(appState)
                .environmentObject(speech)
                .environmentObject(haptics)
                .environmentObject(mathSpeech)
                .environmentObject(audioCue)
        }
    }
}
