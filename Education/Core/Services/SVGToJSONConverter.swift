//
//  SVGToJSONConverter.swift
//  Education
//
//  Converts SVG to structured JSON (like map app approach)
//  Pre-process once, render from JSON

import Foundation

struct SVGToJSONConverter {
    
    /// Convert SVG string to structured JSON data (like map navigation data)
    static func convertToJSON(svgContent: String) -> Data? {
        // Parse SVG using the robust parser
        guard let parsed = SVGToTactileParser.parseToParsedGraphic(svgContent: svgContent) else {
            return nil
        }
        
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try? encoder.encode(parsed)
    }
    
    /// Save converted JSON to file
    static func saveToFile(svgContent: String, filename: String) -> URL? {
        guard let jsonData = convertToJSON(svgContent: svgContent) else {
            return nil
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(filename).json")
        
        do {
            try jsonData.write(to: fileURL)
            return fileURL
        } catch {
            print("[SVGToJSON] Failed to save: \(error)")
            return nil
        }
    }
    
    /// Load and render from JSON file (like map app)
    static func loadFromJSON(data: Data) -> ParsedGraphic? {
        let decoder = JSONDecoder()
        return try? decoder.decode(ParsedGraphic.self, from: data)
    }
}
