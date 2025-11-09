//
//  UploadManager.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import Combine

final class UploadManager: ObservableObject {
    enum State { case idle, confirming(URL), uploading, processing, done(LessonIndexItem), error(String) }
    @Published var state: State = .idle

    func beginConfirm(fileURL: URL) { state = .confirming(fileURL) }

    // Simulate upload + conversion; in a real app you’d call UNAR APIs.
    func uploadAndConvert(simulatedLesson: LessonIndexItem) {
        state = .uploading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.state = .processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self?.state = .done(simulatedLesson)
            }
        }
    }

    func reset() { state = .idle }
}
