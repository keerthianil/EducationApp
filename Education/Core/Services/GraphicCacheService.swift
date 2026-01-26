//
//  GraphicCacheService.swift
//  Education
//
//  Service to cache parsed graphics as JSON for faster loading
//  Parse SVG once, save as JSON, load JSON at runtime

import Foundation

struct GraphicCacheService {
    
    /// Parse SVG and save as JSON to cache
    static func parseAndCache(svgContent: String, cacheKey: String) -> ParsedGraphic? {
        // Parse SVG into ParsedGraphic
        guard let parsed = GraphicParserService.parse(svgContent: svgContent) else {
            return nil
        }
        
        // Save to cache (could be UserDefaults, file system, or Core Data)
        if let jsonData = try? JSONEncoder().encode(parsed) {
            UserDefaults.standard.set(jsonData, forKey: "graphic_cache_\(cacheKey)")
            return parsed
        }
        
        return parsed
    }
    
    /// Load parsed graphic from cache
    static func loadCached(cacheKey: String) -> ParsedGraphic? {
        guard let jsonData = UserDefaults.standard.data(forKey: "graphic_cache_\(cacheKey)"),
              let parsed = try? JSONDecoder().decode(ParsedGraphic.self, from: jsonData) else {
            return nil
        }
        return parsed
    }
    
    /// Parse SVG or load from cache
    static func getParsedGraphic(svgContent: String, cacheKey: String) -> ParsedGraphic? {
        // Try cache first
        if let cached = loadCached(cacheKey: cacheKey) {
            return cached
        }
        
        // Parse and cache
        return parseAndCache(svgContent: svgContent, cacheKey: cacheKey)
    }
    
    // MARK: - Cache Management
    
    /// Clear all cached graphics (both old and new cache formats)
    static func clearAllCache() {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys
        
        // Remove all graphic cache keys
        for key in keys {
            if key.hasPrefix("graphic_cache_") || key.hasPrefix("graphic_json_") {
                defaults.removeObject(forKey: key)
            }
        }
        
        #if DEBUG
        print("[GraphicCache] 🗑️ Cleared all graphic caches")
        #endif
    }
    
    /// Clear cache for a specific graphic
    static func clearCache(for cacheKey: String) {
        UserDefaults.standard.removeObject(forKey: "graphic_cache_\(cacheKey)")
        UserDefaults.standard.removeObject(forKey: "graphic_json_\(cacheKey)")
        
        #if DEBUG
        print("[GraphicCache] 🗑️ Cleared cache for: \(cacheKey)")
        #endif
    }
    
    /// Get count of cached graphics
    static func cacheCount() -> Int {
        let defaults = UserDefaults.standard
        let keys = defaults.dictionaryRepresentation().keys
        return keys.filter { $0.hasPrefix("graphic_cache_") || $0.hasPrefix("graphic_json_") }.count
    }
}
