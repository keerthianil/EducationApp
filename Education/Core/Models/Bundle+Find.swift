//
//  Bundle+Find.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation

/// Robust helper to find a resource in the main bundle by name + extension.
/// This tolerates callers passing either "name" or "name.ext".
func findBundleResource(named base: String, ext: String) -> URL? {
    // 0. If the caller provides a relative path (subdir/name), try that first.
    // Example: "raw_json/scenario_1/page_1" + "json"
    if base.contains("/") {
        let url = URL(fileURLWithPath: base)
        let subdir = url.deletingLastPathComponent().path
        let last = url.lastPathComponent
        let baseName = (last as NSString).deletingPathExtension
        let extToUse = url.pathExtension.isEmpty ? ext : url.pathExtension
        
        if let u = Bundle.main.url(forResource: baseName, withExtension: extToUse, subdirectory: subdir) {
            return u
        }
    }

    // 1. Try the simple case first.
    if let u = Bundle.main.url(forResource: base, withExtension: ext) {
        return u
    }

    // 2. Scan the bundle for *any* files with this extension.
    let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []

    // Exact match: "<base>.<ext>"
    if let u = urls.first(where: { $0.lastPathComponent == "\(base).\(ext)" }) {
        return u
    }

    // 3. If the caller passed "foo.json" as base, strip the ".json".
    let trimmed = (base as NSString).deletingPathExtension
    return urls.first(where: { $0.lastPathComponent == "\(trimmed).\(ext)" })
}
