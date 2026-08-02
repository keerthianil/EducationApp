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

    // MARK: - Math & Geometry seed lessons
    private let mathPracticeLesson = LessonIndexItem(
        id: "math_practice_test",
        title: "Math Practice Test",
        teacher: "Ms. Rivera",
        localFiles: ["math_practice_test"],
        createdAt: Date()
    )

    private let geometricShapesLesson = LessonIndexItem(
        id: "geometric_shapes",
        title: "Geometric Shapes",
        teacher: "Ms. Rivera",
        localFiles: ["geometric_shapes"],
        createdAt: Date().addingTimeInterval(-60)
    )

    // MARK: - Chart & Table seed lessons (each shown separately)

    private let barChartLesson = LessonIndexItem(
        id: "chart_bar",
        title: "Bar Charts",
        teacher: "Ms. Rivera",
        localFiles: ["bar_chart_page"],
        createdAt: Date().addingTimeInterval(-120)
    )

    private let lineGraphLesson = LessonIndexItem(
        id: "chart_line",
        title: "Line Graphs",
        teacher: "Ms. Rivera",
        localFiles: ["line_graph_page"],
        createdAt: Date().addingTimeInterval(-180)
    )

    private let pieChartLesson = LessonIndexItem(
        id: "chart_pie",
        title: "Pie Charts",
        teacher: "Ms. Rivera",
        localFiles: ["pie_chart_page"],
        createdAt: Date().addingTimeInterval(-240)
    )

    private let tablesLesson = LessonIndexItem(
        id: "chart_tables",
        title: "Data Tables",
        teacher: "Ms. Rivera",
        localFiles: ["tables_page"],
        createdAt: Date().addingTimeInterval(-300)
    )

    private let mixedContentLesson = LessonIndexItem(
        id: "chart_mixed",
        title: "Mixed Charts and Tables",
        teacher: "Ms. Rivera",
        localFiles: ["mixed_content_page"],
        createdAt: Date().addingTimeInterval(-360)
    )

    // MARK: - Published lists for dashboard

    /// "Recent Activity" on the dashboard (teacher items + uploads).
    @Published var recent: [LessonIndexItem] = []

    /// Student-uploaded & converted items.
    @Published var downloaded: [LessonIndexItem] = []

    /// Optional banner lesson shown at the top ("New document from …").
    @Published var banner: LessonIndexItem? = nil
    
    /// Files currently being processed (uploading/processing state)
    @Published var processing: [ProcessingFile] = []

    init() {
        applySeedLessons()
    }

    /// Load all seed lessons for the dashboard.
    func applySeedLessons() {
        recent = [
            mathPracticeLesson,
            geometricShapesLesson,
            barChartLesson,
            lineGraphLesson,
            pieChartLesson,
            tablesLesson,
            mixedContentLesson
        ]
        banner = nil
    }

    // MARK: - Mutations

    /// Add a file to processing state (when upload starts)
    func addProcessing(_ item: LessonIndexItem) {
        // Remove if already exists
        processing.removeAll { $0.item.id == item.id }
        // Add to processing with 0% progress
        processing.insert(ProcessingFile(item: item, progress: 0.0), at: 0)
    }
    
    /// Update progress for a processing file
    func updateProcessingProgress(for itemId: String, progress: Double) {
        if let index = processing.firstIndex(where: { $0.item.id == itemId }) {
            processing[index].progress = progress
        }
    }
    
    /// Called by UploadManager when a conversion finishes.
    func addConverted(_ item: LessonIndexItem) {
        // Remove from processing
        processing.removeAll { $0.item.id == item.id }
        
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
    /// If a file fails to load or parse, we just skip it so the app doesn't crash.
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

// MARK: - Processing File Model

struct ProcessingFile: Identifiable {
    let id: String
    let item: LessonIndexItem
    var progress: Double // 0.0 to 1.0
    
    init(item: LessonIndexItem, progress: Double) {
        self.id = item.id
        self.item = item
        self.progress = progress
    }
}
