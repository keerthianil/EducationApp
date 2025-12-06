//
//  EducationApp.swift
//  Education
//

import SwiftUI
import UserNotifications
import Combine

@main
struct EducationApp: App {
    @StateObject var appState = AppState()
    @StateObject var lessonStore = LessonStore()
    @StateObject var haptics = HapticService()
    @StateObject var speech = SpeechService()
    @StateObject var mathSpeech = MathSpeechService()
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Request notification permissions on app launch
        requestNotificationPermissions()
        
        // Set up notification delegate for handling taps
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

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
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    speech.stop(immediate: true)
                }
            }
        }
    }
    
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationDelegate()
    
    @Published var selectedLessonId: String?
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap - open the converted document
        let userInfo = response.notification.request.content.userInfo
        if let lessonId = userInfo["lessonId"] as? String {
            DispatchQueue.main.async {
                self.selectedLessonId = lessonId
            }
        }
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}
