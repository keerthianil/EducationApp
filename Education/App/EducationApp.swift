//
//  EducationApp.swift
//  Education
//

import SwiftUI

@main
struct EducationApp: App {
    @StateObject var appState = AppState()
    @StateObject var lessonStore = LessonStore()
    @StateObject var haptics = HapticService()
    @StateObject var speech = SpeechService()
    @StateObject var mathSpeech = MathSpeechService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                // Check if onboarding is completed
                if appState.hasCompletedOnboarding {
                    DashboardView()
                } else {
                    AboutView()
                }
            }
            .environmentObject(appState)
            .environmentObject(lessonStore)
            .environmentObject(haptics)
            .environmentObject(speech)
            .environmentObject(mathSpeech)
            .preferredColorScheme(.light)
            .onChange(of: scenePhase) { phase in
                if phase == .background {
                    speech.stop(immediate: true)
                }
            }
        }
    }
}
