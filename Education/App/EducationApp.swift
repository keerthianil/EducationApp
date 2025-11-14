import SwiftUI

@main
struct EducationApp: App {
    @StateObject var lessonStore = LessonStore()
    @StateObject var haptics = HapticService()
    @StateObject var speech = SpeechService()
    @StateObject var mathSpeech = MathSpeechService()

    var body: some Scene {
        WindowGroup {
            NavigationStack {  // ← ADD THIS LINE!
                AboutView()
            }  // ← AND THIS CLOSING BRACE!
            .environmentObject(lessonStore)
            .environmentObject(haptics)
            .environmentObject(speech)
            .environmentObject(mathSpeech)
        }
    }
}