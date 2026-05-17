//
//  LessonStore+API.swift
//  Education
//
//  Extension to LessonStore that adds:
//  1. Saving API-returned JSON to Documents directory
//  2. Loading JSON from Documents (not just from the bundle)
//  3. Removing processing items
//
//  Add this file to your Xcode project alongside LessonStore.swift
//

import Foundation

extension LessonStore {
    
    // MARK: - Documents Directory for Converted Files
    
    /// Directory where API-converted JSON files are saved.
    /// This persists across app launches (unlike the bundle, which is read-only).
    private var convertedDocsDirectory: URL? {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = docs.appendingPathComponent("ConvertedLessons")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    // MARK: - Save Converted JSON
    
    /// Save a page of JSON data returned by the API to the Documents directory.
    /// Returns true if successful.
    ///
    /// - Parameters:
    ///   - data: Raw JSON data from the API
    ///   - filename: The filename to save as (without .json extension)
    func saveConvertedJSON(data: Data, filename: String) -> Bool {
        guard let dir = convertedDocsDirectory else {
            print("❌ Cannot access Documents directory")
            return false
        }
        
        let fileURL = dir.appendingPathComponent("\(filename).json")
        
        do {
            try data.write(to: fileURL, options: .atomic)
            #if DEBUG
            print("✅ Saved converted JSON: \(fileURL.lastPathComponent)")
            #endif
            return true
        } catch {
            print("❌ Failed to save JSON: \(error)")
            return false
        }
    }
    
    // MARK: - Load JSON from Documents Directory
    
    /// Try to load JSON from the Documents/ConvertedLessons directory.
    /// Returns nil if the file doesn't exist there.
    func loadConvertedJSON(named filename: String) -> Data? {
        guard let dir = convertedDocsDirectory else { return nil }
        
        let name = (filename as NSString).deletingPathExtension
        let fileURL = dir.appendingPathComponent("\(name).json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        return try? Data(contentsOf: fileURL)
    }
    
    // MARK: - Enhanced Node Loading (checks Documents first, then bundle)
    
    /// Load nodes for a list of filenames.
    /// Checks Documents/ConvertedLessons first (for API results),
    /// then falls back to the app bundle (for pre-bundled teacher content).
    func loadNodesFromAnywhere(forFilenames files: [String]) -> [Node] {
        var allNodes: [Node] = []
        
        for filename in files {
            // 1. Try Documents directory first (API-converted files)
            if let data = loadConvertedJSON(named: filename) {
                let pageNodes = FlexibleLessonParser.parseNodes(from: data)
                if !pageNodes.isEmpty {
                    allNodes.append(contentsOf: pageNodes)
                    continue
                }
            }
            
            // 2. Fall back to bundle (pre-bundled teacher content)
            if let data = try? loadBundleJSON(named: filename) {
                let pageNodes = FlexibleLessonParser.parseNodes(from: data)
                allNodes.append(contentsOf: pageNodes)
            }
        }
        
        return allNodes
    }
    
    // MARK: - Remove Processing Item
    
    /// Remove an item from the processing list (e.g., on error).
    func removeProcessing(for itemId: String) {
        processing.removeAll { $0.item.id == itemId }
    }
    
    // MARK: - Clean Up Old Converted Files
    
    /// Delete converted JSON files older than a certain number of days.
    /// Call this on app launch to prevent unbounded storage growth.
    func cleanupOldConversions(olderThanDays days: Int = 30) {
        guard let dir = convertedDocsDirectory else { return }
        let fm = FileManager.default
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        for file in files {
            guard let attrs = try? fm.attributesOfItem(atPath: file.path),
                  let created = attrs[.creationDate] as? Date,
                  created < cutoff else { continue }
            try? fm.removeItem(at: file)
        }
    }
}
