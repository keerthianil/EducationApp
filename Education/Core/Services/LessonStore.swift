//
//  LessonStore.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import Combine

/// One lesson in the dashboard / recent list.
struct LessonIndexItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let teacher: String?          // nil for student uploads
    let localFiles: [String]      // JSON page filenames in bundle (without or with .json)
    let createdAt: Date
}

final class LessonStore: ObservableObject {

    // MARK: - Seed lessons from teacher (3 sample PDFs)

    /// Accessibility article – samples in `raw_json/sample1`
    let teacherSeed: LessonIndexItem? = LessonIndexItem(
        id: "sample1_accessibility",
        title: "The Science of Accessible Design",
        teacher: "Ms. Rivera",
        localFiles: [
            "sample1_page1",      // looks up sample1_page1.json in bundle
            "sample1_page2"
        ],
        createdAt: Date()
    )

    /// Area of Compound Figures – `raw_json/sample2`
    private let sample2Lesson = LessonIndexItem(
        id: "sample2_compound",
        title: "Area of Compound Figures",
        teacher: "Ms. Rivera",
        localFiles: [
            "sample2_page1",
            "sample2_page2"
        ],
        createdAt: Date().addingTimeInterval(-3600)
    )

    /// Precalculus packet – `raw_json/sample3`
    private let sample3Lesson = LessonIndexItem(
        id: "sample3_precalculus",
        title: "Precalculus Math Packet",
        teacher: "Ms. Rivera",
        localFiles: [
            "sample3_page1",
            "sample3_page2",
            "sample3_page3",
            "sample3_page4",
            "sample3_page5",
            "sample3_page6",
            "sample3_page7",
            "sample3_page8",
            "sample3_page9",
            "sample3_page10"
        ],
        createdAt: Date().addingTimeInterval(-7200)
    )

    // MARK: - Published lists for dashboard

    /// “Recent Activity” on the dashboard (teacher items + uploads).
    @Published var recent: [LessonIndexItem] = []

    /// Student-uploaded & converted items.
    @Published var downloaded: [LessonIndexItem] = []

    /// Optional banner lesson shown at the top (“New document from …”).
    @Published var banner: LessonIndexItem? = nil

    init() {
        // Seed dashboard with all three teacher lessons so they’re visible
        if let seed = teacherSeed {
            recent = [seed, sample2Lesson, sample3Lesson]
            banner = seed
        }
    }

    // MARK: - Mutations

    /// Called by UploadManager when a conversion finishes.
    func addConverted(_ item: LessonIndexItem) {
        // Track in uploaded list
        downloaded.insert(item, at: 0)

        // Also push to recent list (most recent first)
        recent.removeAll { $0.id == item.id }
        recent.insert(item, at: 0)

        // And show banner for the latest converted file
        banner = item
    }

    // MARK: - JSON loading + parsing

    /// Load one JSON file from the app bundle.
    ///
    /// Accepts either:
    ///  - "sample1_page1"      → looks for sample1_page1.json
    ///  - "sample1_page1.json" → also works
    ///
    /// Uses `findBundleResource` so files can live inside
    /// `Resources/raw_json/sampleX/...` and not just at the bundle root.
    func loadBundleJSON(named file: String) throws -> Data {
        // Allow callers to pass "foo" or "foo.json"
        let parts = file.split(separator: ".")
        let name = String(parts.first ?? "")
        let ext  = parts.count > 1 ? String(parts.last!) : "json"

        guard let url = findBundleResource(named: name, ext: ext) else {
            throw NSError(
                domain: "LessonStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Missing \(file) (\(name).\(ext)) in app bundle"]
            )
        }

        return try Data(contentsOf: url)
    }

    /// Load and parse nodes for a list of filenames.
    /// If a file fails to load or parse, we just skip it so the app doesn’t crash.
    func loadNodes(forFilenames files: [String]) -> [Node] {
        var all: [Node] = []

        for f in files {
            if let data = try? loadBundleJSON(named: f) {
                let pageNodes = FlexibleLessonParser.parseNodes(from: data)
                all.append(contentsOf: pageNodes)
            }
        }

        return all
    }
}
