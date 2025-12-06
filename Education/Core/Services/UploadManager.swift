//
//  UploadManager.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import Combine
import UserNotifications

final class UploadManager: ObservableObject {

    enum State {
        case idle
        case confirming(URL)
        case uploading
        case processing
        case done(LessonIndexItem)
        case error(String)
    }

    @Published var state: State = .idle
    @Published var progress: Double = 0.0 // 0.0 to 1.0
    
    weak var lessonStore: LessonStore?
    private var currentLessonId: String?

    func beginConfirm(fileURL: URL) {
        state = .confirming(fileURL)
    }

    /// Demo mapping: the 3 known PDFs -> bundled JSON pages.
    /// NO network call here; just pretend we sent to UNAR API.
    func uploadAndConvert(fileURL: URL) {
        let baseName = fileURL.deletingPathExtension().lastPathComponent.lowercased()

        let mapped: LessonIndexItem?

        // 1) The Science of Accessible Design
        if baseName.contains("accessible") {
            mapped = LessonIndexItem(
                id: "sample1",
                title: "The Science of Accessible Design",
                teacher: "Ms. Rivera",
                localFiles: ["sample1_page1.json", "sample1_page2.json"],
                createdAt: Date()
            )

        // 2) Area of Compound Figures
        } else if baseName.contains("compound") {
            mapped = LessonIndexItem(
                id: "sample2",
                title: "Area of Compound Figures",
                teacher: "Ms. Rivera",
                localFiles: ["sample2_page1.json", "sample2_page2.json"],
                createdAt: Date()
            )

        // 3) Precalculus Math Packet 4
        } else if baseName.contains("precalculus") {
            mapped = LessonIndexItem(
                id: "sample3",
                title: "Precalculus Math Packet 4",
                teacher: "Ms. Rivera",
                localFiles: (1...10).map { "sample3_page\($0).json" },
                createdAt: Date()
            )
        
        // 4) Algebra Practice 4 (for Use Case 2)
        } else if baseName.contains("algebra") {
            mapped = LessonIndexItem(
                id: "algebra_practice_4",
                title: "Algebra Practice 4",
                teacher: nil, // Student upload
                localFiles: ["sample3_page1.json", "sample3_page2.json"], // Use sample3 for now
                createdAt: Date()
            )

        } else {
            mapped = nil
        }

        guard let lesson = mapped else {
            state = .error("Unknown sample. In this demo, upload one of the 3 bundled PDFs.")
            return
        }

        // Add to processing state immediately
        currentLessonId = lesson.id
        lessonStore?.addProcessing(lesson)
        progress = 0.0
        
        // Simulate server upload + conversion
        // Per Use Case 2: Upload completes quickly, but processing takes a few minutes
        state = .uploading
        
        // Simulate upload progress (0% to 30%)
        simulateProgress(from: 0.0, to: 0.3, duration: 1.0) { [weak self] in
            guard let self = self else { return }
            self.state = .processing
            
            // Processing takes longer (simulate "a few minutes" - using shorter time for demo)
            // Progress from 30% to 100%
            self.simulateProgress(from: 0.3, to: 1.0, duration: 3.0) { [weak self] in
                guard let self = self else { return }
                self.state = .done(lesson)
                self.progress = 1.0
                
                // Add to converted items
                self.lessonStore?.addConverted(lesson)
                
                // Schedule local notification for conversion completion
                self.scheduleCompletionNotification(for: lesson)
            }
        }
    }
    
    /// Simulate progress updates
    private func simulateProgress(from start: Double, to end: Double, duration: TimeInterval, completion: @escaping () -> Void) {
        let steps = 20
        let stepDuration = duration / Double(steps)
        let stepSize = (end - start) / Double(steps)
        
        var currentStep = 0
        let timer = Timer.scheduledTimer(withTimeInterval: stepDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            self.progress = start + (stepSize * Double(currentStep))
            if let lessonId = self.currentLessonId {
                self.lessonStore?.updateProcessingProgress(for: lessonId, progress: self.progress)
            }
            
            if currentStep >= steps {
                timer.invalidate()
                completion()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    func reset() {
        state = .idle
        progress = 0.0
        currentLessonId = nil
    }
    
    // MARK: - Local Notifications
    
    /// Schedule a local notification when conversion completes
    /// Per Use Case 2: "Your converted file is ready — [filename]"
    private func scheduleCompletionNotification(for lesson: LessonIndexItem) {
        let content = UNMutableNotificationContent()
        content.title = "Your converted file is ready"
        content.body = lesson.title
        content.sound = .default
        content.userInfo = [
            "lessonId": lesson.id,
            "lessonTitle": lesson.title
        ]
        
        // Schedule notification immediately (for demo purposes)
        // In real app, this would be triggered by server push notification
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "conversion_complete_\(lesson.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
}
