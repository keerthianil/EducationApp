//
//  UploadManager.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import Combine

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

        } else {
            mapped = nil
        }

        guard let lesson = mapped else {
            state = .error("Unknown sample. In this demo, upload one of the 3 bundled PDFs.")
            return
        }

        // Simulate server upload + conversion
        state = .uploading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.state = .processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                self?.state = .done(lesson)
            }
        }
    }

    func reset() {
        state = .idle
    }
}
