//
//  UploadManager.swift
//  Education
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
    @Published var progress: Double = 0.0
    
    weak var lessonStore: LessonStore?
    private var currentLessonId: String?

    func beginConfirm(fileURL: URL) {
        state = .confirming(fileURL)
    }

    func uploadAndConvert(fileURL: URL) {
        let baseName = fileURL.deletingPathExtension().lastPathComponent.lowercased()

        let mapped: LessonIndexItem?

        if baseName.contains("accessible") || baseName.contains("science") {
            mapped = LessonIndexItem(
                id: "sample1_upload_\(UUID().uuidString.prefix(8))",
                title: "The Science of Accessible Design",
                teacher: nil,
                localFiles: ["sample1_page1.json"], // sample1_page2.json temporarily removed for testing
                createdAt: Date()
            )
        } else if baseName.contains("compound") || baseName.contains("area") || baseName.contains("figures") {
            mapped = LessonIndexItem(
                id: "sample2_upload_\(UUID().uuidString.prefix(8))",
                title: "Area of Compound Figures",
                teacher: nil,
                localFiles: ["sample2_page1.json"], // sample2_page2.json temporarily removed (wrongly rendered)
                createdAt: Date()
            )
        // Precalculus file mapping - temporarily commented out for user testing
        // We are only using 2 documents for the first round of user testing
        /*
        } else if baseName.contains("precalculus") || baseName.contains("math packet") || baseName.contains("calculus") {
            mapped = LessonIndexItem(
                id: "sample3_upload_\(UUID().uuidString.prefix(8))",
                title: "Precalculus Math Packet 4",
                teacher: nil,
                localFiles: (1...10).map { "sample3_page\($0).json" },
                createdAt: Date()
            )
        */
        } else if baseName.contains("algebra") {
            // Map algebra to sample2 (Area of Compound Figures) for testing
            mapped = LessonIndexItem(
                id: "algebra_upload_\(UUID().uuidString.prefix(8))",
                title: "Algebra Practice 4",
                teacher: nil,
                localFiles: ["sample2_page1.json"], // sample2_page2.json temporarily removed (wrongly rendered)
                createdAt: Date()
            )
        } else {
            mapped = nil
        }

        guard let lesson = mapped else {
            state = .error("Unknown file. Please select a supported PDF.")
            return
        }

        currentLessonId = lesson.id
        lessonStore?.addProcessing(lesson)
        progress = 0.0
        
        state = .uploading
        
        // VoiceOver: Single "Processing" announcement - delay long enough for sheet to dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            UIAccessibility.post(notification: .announcement, argument: "Processing")
        }
        
        simulateProgress(from: 0.0, to: 0.3, duration: 1.0) { [weak self] in
            guard let self = self else { return }
            self.state = .processing
            
            self.simulateProgress(from: 0.3, to: 1.0, duration: 3.0) { [weak self] in
                guard let self = self else { return }
                self.state = .done(lesson)
                self.progress = 1.0
                self.lessonStore?.addConverted(lesson)
                self.scheduleCompletionNotification(for: lesson)
                
                // VoiceOver: Single "Complete" announcement
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    UIAccessibility.post(notification: .announcement, argument: "Complete")
                }
            }
        }
    }
    
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
    
    private func scheduleCompletionNotification(for lesson: LessonIndexItem) {
        let content = UNMutableNotificationContent()
        content.title = "File ready"
        content.body = lesson.title
        content.sound = .default
        content.userInfo = [
            "lessonId": lesson.id,
            "lessonTitle": lesson.title
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "conversion_complete_\(lesson.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
