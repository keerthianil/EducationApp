import SwiftUI

@main
struct EducationApp: App {
    @StateObject var lessonStore = LessonStore()
    @StateObject var haptics = HapticService()
    @StateObject var speech = SpeechService()
    @StateObject var mathSpeech = MathSpeechService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                AboutView()
            }
            .environmentObject(speech)
                    .onChange(of: scenePhase) { phase in
                        if phase == .background {
                            speech.stop(immediate: true)
                        }
                    }
            .environmentObject(lessonStore)
            .environmentObject(haptics)
            .environmentObject(speech)
            .environmentObject(mathSpeech)
            .preferredColorScheme(.light)
        }
    }
}
