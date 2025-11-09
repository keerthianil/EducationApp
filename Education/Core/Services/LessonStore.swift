//
//  LessonStore.swift .swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//
import Foundation
import Combine

struct LessonIndexItem: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let teacher: String?
    let localFiles: [String]     // e.g. ["sample1_page1.json","sample1_page2.json"]
    let createdAt: Date
}

final class LessonStore: ObservableObject {
    @Published var recent: [LessonIndexItem] = []
    @Published var downloaded: [LessonIndexItem] = []

    init() {
        // Use Case 1 banner → your Photosynthesis (sample1)
        recent = [
            LessonIndexItem(
                id: "photosynthesis",
                title: "Photosynthesis Worksheet",
                teacher: "Ms. Rivera",
                localFiles: ["sample1_page1.json", "sample1_page2.json"],
                createdAt: Date()
            )
        ]
    }

    /// Load a JSON file from anywhere in the bundle.
    func loadBundleJSON(named file: String) throws -> Data {
        let base = (file as NSString).deletingPathExtension
        guard let url = findBundleResource(named: base, ext: "json") else {
            throw NSError(domain: "LessonStore", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Missing \(file) in app bundle."])
        }
        return try Data(contentsOf: url)
    }

    /// Merge nodes from multiple JSON pages.
    func loadNodes(forFilenames files: [String]) -> [Node] {
        var nodes: [Node] = []
        for f in files {
            guard let data = try? loadBundleJSON(named: f),
                  let doc = try? JSONDecoder().decode(LessonDocument.self, from: data) else { continue }
            nodes.append(contentsOf: doc.content)
        }
        return nodes
    }
}
