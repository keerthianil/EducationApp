import SwiftUI

@main
struct EducationApp: App {
    @StateObject var lessonStore = LessonStore()
    @StateObject var haptics = HapticService()
    @StateObject var speech = SpeechService()
    @StateObject var mathSpeech = MathSpeechService()

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(lessonStore)
                .environmentObject(haptics)
                .environmentObject(speech)
                .environmentObject(mathSpeech)
        }
    }
}
