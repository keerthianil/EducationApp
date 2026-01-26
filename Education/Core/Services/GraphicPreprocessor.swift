//
//  GraphicPreprocessor.swift
//  Education
//
//  Pre-process SVG to JSON files (like map app)
//  Run once to convert all SVGs to JSON, then ship JSON files in bundle

import Foundation

// Import findBundleResource from Bundle+Find
// (Assuming it's a global function or extension)

struct GraphicPreprocessor {
    
    /// Pre-process all SVGs in JSON files and save as separate JSON graphics
    /// This should be run as a build script or one-time migration
    static func preprocessAllGraphics() {
        let lessonStore = LessonStore()
        
        // Find all JSON lesson files
        let sampleFiles = [
            "sample1_page1", "sample1_page2",
            "sample2_page1", "sample2_page2",
            "sample3_page1", "sample3_page2", "sample3_page3",
            "sample3_page4", "sample3_page5", "sample3_page6",
            "sample3_page7", "sample3_page8", "sample3_page9", "sample3_page10"
        ]
        
        for filename in sampleFiles {
            guard let data = try? lessonStore.loadBundleJSON(named: filename) else {
                continue
            }
            
            let nodes = FlexibleLessonParser.parseNodes(from: data)
            
            for (index, node) in nodes.enumerated() {
                if case .svgNode(let svg, let title, _) = node {
                    // Convert SVG to JSON
                    if let jsonData = SVGToJSONConverter.convertToJSON(svgContent: svg) {
                        // Save to processed_graphics folder
                        let outputName = "\(filename)_graphic_\(index).json"
                        saveProcessedGraphic(data: jsonData, filename: outputName)
                        print("✅ Pre-processed: \(outputName)")
                    }
                }
            }
        }
    }
    
    private static func saveProcessedGraphic(data: Data, filename: String) {
        // Save to Documents directory (or could save to bundle during build)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let graphicsDir = documentsPath.appendingPathComponent("processed_graphics")
        
        try? FileManager.default.createDirectory(at: graphicsDir, withIntermediateDirectories: true)
        
        let fileURL = graphicsDir.appendingPathComponent(filename)
        try? data.write(to: fileURL)
    }
    
    /// Load pre-processed graphic JSON from bundle
    static func loadPreprocessedGraphic(named: String) -> ParsedGraphic? {
        // Try documents directory (for pre-processed files)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("processed_graphics/\(named).json")
        if let data = try? Data(contentsOf: fileURL),
           let graphic = SVGToJSONConverter.loadFromJSON(data: data) {
            return graphic
        }
        
        return nil
    }
}
