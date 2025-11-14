//
//  ResourceLocator.swift
//  Education
//
//  Created by Keerthi Reddy on 11/10/25.
//

import Foundation

enum ResourceLocator {
    /// Accepts:
    ///  - "output_html/sample3/Precalculus Math Packet 4"
    ///  - "output_html/sample3/Precalculus Math Packet 4.html"
    /// Returns the file URL if it exists in the bundle.
    static func htmlURL(_ relativePath: String) -> URL? {
        // Split into subdirectory and filename
        let parts = relativePath.split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return nil }
        let fileWithMaybeExt = parts.last!
        let subdir = parts.dropLast().joined(separator: "/")

        // Normalize extension
        let baseName: String
        if fileWithMaybeExt.lowercased().hasSuffix(".html") {
            baseName = String(fileWithMaybeExt.dropLast(5))
        } else {
            baseName = fileWithMaybeExt
        }

        // This call handles spaces/Unicode perfectly
        return Bundle.main.url(forResource: baseName, withExtension: "html", subdirectory: subdir)
    }
}
