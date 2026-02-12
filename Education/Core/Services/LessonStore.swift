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

    // MARK: - Seed lessons from teacher (2 sample PDFs - precalculus removed for user testing)

    /// Accessibility article – samples in `raw_json/sample1`
    /// Page 2 removed for testing - temporarily using only page 1
    let teacherSeed: LessonIndexItem? = LessonIndexItem(
        id: "sample1_accessibility",
        title: "The Science of Accessible Design",
        teacher: "Ms. Rivera",
        localFiles: [
            "sample1_page1"      // looks up sample1_page1.json in bundle
            // "sample1_page2" - temporarily removed for testing
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

    // MARK: - Practice Scenario (Flow 1) seed lessons
    // New documents live in `Resources/raw_json/practice_json/`
    private let practiceScenarioLesson1 = LessonIndexItem(
        id: "practice_scenario_1",
        title: "Math Practice Test 1",
        teacher: "Ms. Rivera",
        localFiles: ["page_1"],
        createdAt: Date()
    )

    private let practiceScenarioLesson2 = LessonIndexItem(
        id: "practice_scenario_2",
        title: "Math Practice Test 2",
        teacher: "Ms. Rivera",
        localFiles: ["practice_page_2"],
        createdAt: Date().addingTimeInterval(-60)
    )
    
    // MARK: - Scenario 1 (Flow 2) seed lessons
    // New documents live in `Resources/raw_json/scenario_1/`
    private let scenario1Lesson1 = LessonIndexItem(
        id: "scenario_1_unit_1",
        title: "Unit 1: Introductory Topics",
        teacher: "Ms. Rivera",
        localFiles: ["scenario1_page_1"],
        createdAt: Date()
    )
    
    private let scenario1Lesson2 = LessonIndexItem(
        id: "scenario_1_unit_2",
        title: "Unit 2: Integers",
        teacher: "Ms. Rivera",
        localFiles: ["scenario1_page_2"],
        createdAt: Date().addingTimeInterval(-60)
    )
    
    // MARK: - Scenario 2 (Flow 3) seed lessons
    // New documents live in `Resources/raw_json/scenario_2/`
    private let scenario2Lesson1 = LessonIndexItem(
        id: "scenario_2_shapes_1",
        title: "Shapes and Geometry (1)",
        teacher: "Ms. Rivera",
        localFiles: ["scenario2_page_1"],
        createdAt: Date()
    )
    
    private let scenario2Lesson2 = LessonIndexItem(
        id: "scenario_2_shapes_2",
        title: "Shapes and Geometry (2)",
        teacher: "Ms. Rivera",
        localFiles: ["scenario2_page_2"],
        createdAt: Date().addingTimeInterval(-60)
    )

    /// Precalculus packet – `raw_json/sample3` - temporarily commented out for user testing
    /// We will only use 2 documents for the first round of user testing
    /*
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
    */

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
        // Default seed (used by Flow 2 / Flow 3 until migrated)
        applySeedLessons(forFlow: 2)
    }

    /// Apply flow-specific seed lessons.
    /// Phase 1: only Flow 1 ("Practice Scenario") uses the new practice_json docs.
    func applySeedLessons(forFlow flow: Int) {
        switch flow {
        case 1:
            // Practice Scenario
            recent = [practiceScenarioLesson1, practiceScenarioLesson2]
            banner = nil
            #if DEBUG
            print("[Practice Scenario] Loading JSON files: \(practiceScenarioLesson1.localFiles) and \(practiceScenarioLesson2.localFiles)")
            #endif
        case 2:
            // Scenario 1
            recent = [scenario1Lesson1, scenario1Lesson2]
            banner = nil
            #if DEBUG
            print("[Scenario 1] Loading JSON files: \(scenario1Lesson1.localFiles) and \(scenario1Lesson2.localFiles)")
            #endif
        case 3:
            // Scenario 2
            recent = [scenario2Lesson1, scenario2Lesson2]
            banner = nil
            #if DEBUG
            print("[Scenario 2] Loading JSON files: \(scenario2Lesson1.localFiles) and \(scenario2Lesson2.localFiles)")
            #endif
        default:
            if let seed = teacherSeed {
                recent = [seed, sample2Lesson]
                banner = seed
            } else {
                recent = [sample2Lesson]
                banner = nil
            }
        }
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
