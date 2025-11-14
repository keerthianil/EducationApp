//
//  LessonStore.swift .swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.


import Foundation
import Combine

/// One lesson in the dashboard / recent list.
struct LessonIndexItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let teacher: String?          // nil for student uploads
    let localFiles: [String]      // JSON page filenames in bundle
    let createdAt: Date
}

final class LessonStore: ObservableObject {

    // MARK: - Seed lesson from teacher (Use Case 1)

    private(set) var teacherSeed: LessonIndexItem? = LessonIndexItem(
        id: "photosynthesis",
        title: "Photosynthesis Worksheet",
        teacher: "Ms. Rivera",
        localFiles: ["sample1_page1.json", "sample1_page2.json"],
        createdAt: Date()
    )

    // MARK: - Published lists for dashboard

    /// “Recent Activity” on the dashboard (teacher items + uploads).
    @Published var recent: [LessonIndexItem] = []

    /// Student-uploaded & converted items.
    @Published var downloaded: [LessonIndexItem] = []

    /// Optional banner lesson shown at the top (“New document from …”).
    @Published var banner: LessonIndexItem? = nil

    init() {
        if let seed = teacherSeed {
            recent = [seed]
            banner = seed
        }
    }

    // MARK: - Mutations

    /// Called by UploadManager when a conversion finishes.
    func addConverted(_ item: LessonIndexItem) {
        downloaded.insert(item, at: 0)

        // Also push to recent list (most recent first)
        recent.removeAll { $0.id == item.id }
        recent.insert(item, at: 0)

        // And show banner for the latest converted file
        banner = item
    }

    // MARK: - JSON loading + parsing

    func loadBundleJSON(named file: String) throws -> Data {
        let parts = file.split(separator: ".")
        let name = String(parts.first ?? "")
        let ext  = String(parts.last ?? "json")

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw NSError(
                domain: "LessonStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Missing \(file) in app bundle"]
            )
        }

        return try Data(contentsOf: url)
    }

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

