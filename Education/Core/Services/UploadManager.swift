//
//  UploadManager.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import Combine
import UserNotifications
import UIKit

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
        if baseName.contains("accessible") || baseName.contains("science") {
            mapped = LessonIndexItem(
                id: "sample1_upload_\(UUID().uuidString.prefix(8))",
                title: "The Science of Accessible Design",
                teacher: nil, // Student upload
                localFiles: ["sample1_page1.json", "sample1_page2.json"],
                createdAt: Date()
            )

        // 2) Area of Compound Figures
        } else if baseName.contains("compound") || baseName.contains("area") || baseName.contains("figures") {
            mapped = LessonIndexItem(
                id: "sample2_upload_\(UUID().uuidString.prefix(8))",
                title: "Area of Compound Figures",
                teacher: nil, // Student upload
                localFiles: ["sample2_page1.json", "sample2_page2.json"],
                createdAt: Date()
            )

        // 3) Precalculus Math Packet 4
        } else if baseName.contains("precalculus") || baseName.contains("math packet") || baseName.contains("calculus") {
            mapped = LessonIndexItem(
                id: "sample3_upload_\(UUID().uuidString.prefix(8))",
                title: "Precalculus Math Packet 4",
                teacher: nil, // Student upload
                localFiles: (1...10).map { "sample3_page\($0).json" },
                createdAt: Date()
            )
        
        // 4) Algebra Practice 4 (legacy support)
        } else if baseName.contains("algebra") {
            mapped = LessonIndexItem(
                id: "algebra_upload_\(UUID().uuidString.prefix(8))",
                title: "Algebra Practice 4",
                teacher: nil, // Student upload
                localFiles: ["sample3_page1.json", "sample3_page2.json"],
                createdAt: Date()
            )

        } else {
            mapped = nil
        }

        guard let lesson = mapped else {
            state = .error("Unknown file. Please select one of the sample PDFs: Accessible Design, Compound Figures, or Precalculus.")
            
            // VoiceOver announcement for error
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Error: Unknown file. Please select one of the sample PDFs."
                )
            }
            return
        }

        // Add to processing state immediately
        currentLessonId = lesson.id
        lessonStore?.addProcessing(lesson)
        progress = 0.0
        
        // Simulate server upload + conversion
        state = .uploading
        
        // VoiceOver: Announce upload started
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            UIAccessibility.post(
                notification: .announcement,
                argument: "Uploading \(lesson.title)"
            )
        }
        
        // Simulate upload progress (0% to 30%)
        simulateProgress(from: 0.0, to: 0.3, duration: 1.0) { [weak self] in
            guard let self = self else { return }
            self.state = .processing
            
            // VoiceOver: Announce processing started
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Upload complete. Now processing \(lesson.title). This may take a moment."
                )
            }
            
            // Processing takes longer (simulate "a few minutes" - using shorter time for demo)
            self.simulateProgress(from: 0.3, to: 1.0, duration: 3.0) { [weak self] in
                guard let self = self else { return }
                self.state = .done(lesson)
                self.progress = 1.0
                
                // Add to converted items
                self.lessonStore?.addConverted(lesson)
                
                // Schedule local notification for conversion completion
                self.scheduleCompletionNotification(for: lesson)
                
                // VoiceOver: Announce completion
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Processing complete. \(lesson.title) is now ready to view."
                    )
                }
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
            
            // VoiceOver: Announce progress at key milestones (25%, 50%, 75%)
            let progressPercent = Int(self.progress * 100)
            if progressPercent == 25 || progressPercent == 50 || progressPercent == 75 {
                // Only announce if VoiceOver is running to avoid spam
                if UIAccessibility.isVoiceOverRunning {
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "\(progressPercent) percent complete"
                    )
                }
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
