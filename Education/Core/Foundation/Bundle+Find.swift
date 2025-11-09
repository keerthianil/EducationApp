//
//  Bundle+Find.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//
import Foundation


func findBundleResource(named base: String, ext: String) -> URL? {
    // Try direct
    if let u = Bundle.main.url(forResource: base, withExtension: ext) { return u }

    // Scan bundle
    let urls = Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []

    // Exact "<base>.<ext>"
    if let u = urls.first(where: { $0.lastPathComponent == "\(base).\(ext)" }) { return u }

    // Accept callers that pass "foo.json" as `base`
    let trimmed = (base as NSString).deletingPathExtension
    return urls.first(where: { $0.lastPathComponent == "\(trimmed).\(ext)" })
}
