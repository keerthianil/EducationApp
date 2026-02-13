//
//  EducationApp.swift
//  Education
//

import SwiftUI
import Combine

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
                ChooseFlowView()
            }
            .environmentObject(appState)
            .environmentObject(lessonStore)
            .environmentObject(haptics)
            .environmentObject(speech)
            .environmentObject(mathSpeech)
            .preferredColorScheme(.light)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background { speech.stop(immediate: true) }
            }
        }
    }
}

// MARK: - Notification Delegate (kept for compatibility but no longer auto-initialized)

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationDelegate()
    @Published var selectedLessonId: String?

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let lessonId = userInfo["lessonId"] as? String {
            DispatchQueue.main.async { self.selectedLessonId = lessonId }
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // CHANGED: Don't show notification banners
        completionHandler([])
    }
}
