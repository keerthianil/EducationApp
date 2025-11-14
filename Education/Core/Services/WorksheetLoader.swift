//
//  WorksheetLoader.swift
//  Education
//
//  Created by Keerthi Reddy on 11/13/25.
//

import Foundation

struct WorksheetLoader {

    /// Build worksheet *pages* from the lesson’s JSON files.
    /// - Each filename (JSON) is treated as ONE page.
    /// - Inside a page we currently keep a single WorksheetItem whose nodes
    ///   are split visually by `QuestionNodeView`.
    static func loadPages(
        lessonStore: LessonStore,
        filenames: [String]
    ) -> [[WorksheetItem]] {

        var pages: [[WorksheetItem]] = []

        // 1 JSON file -> 1 page -> 1 WorksheetItem
        for (pageIndex, filename) in filenames.enumerated() {
            let nodesForPage = lessonStore.loadNodes(forFilenames: [filename])

            guard !nodesForPage.isEmpty else { continue }

            // Use first heading as title if it exists
            var title: String? = nil
            if let first = nodesForPage.first,
               case let .heading(_, text) = first {
                title = text
            }

            let item = WorksheetItem(
                index: pageIndex + 1,
                title: title,
                nodes: nodesForPage
            )

            pages.append([item])
        }

        // If for some weird reason we didn’t get anything,
        // fall back to splitting the merged nodes by “Question …” headings.
        if pages.isEmpty {
            let mergedNodes = lessonStore.loadNodes(forFilenames: filenames)
            let fromHeadings = WorksheetItem.makeItems(from: mergedNodes)

            if !fromHeadings.isEmpty {
                return fromHeadings.map { [$0] }
            }

            // Absolute fallback: one big page with one item
            if !mergedNodes.isEmpty {
                let single = WorksheetItem(index: 1, title: nil, nodes: mergedNodes)
                return [[single]]
            }
        }

        return pages
    }
}
