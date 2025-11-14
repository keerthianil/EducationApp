//
//  WorksheetItem.swift
//  Education
//
//  Created by Keerthi Reddy on 11/13/25.
//

import Foundation

struct WorksheetItem: Identifiable, Hashable {
    let id: UUID
    let index: Int                  // Page / question number (1-based)
    let title: String?              // Optional heading
    let nodes: [Node]               // Nodes belonging to this item
    let searchableText: String      // Flattened text for search

    init(index: Int, title: String?, nodes: [Node]) {
        self.id = UUID()
        self.index = index
        self.title = title
        self.nodes = nodes
        self.searchableText = WorksheetItem.buildSearchText(from: nodes)
    }

    // Manual Hashable so Node doesn’t need to be Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WorksheetItem, rhs: WorksheetItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Public helpers

extension WorksheetItem {

    /// Build items from ONE flat node list.
    /// Heuristic: headings whose text contains "question" start a new item.
    static func makeItems(from nodes: [Node]) -> [WorksheetItem] {
        var items: [WorksheetItem] = []
        var buffer: [Node] = []
        var currentTitle: String?
        var qIndex = 0

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            let indexToUse = qIndex == 0 ? 1 : qIndex
            let item = WorksheetItem(
                index: indexToUse,
                title: currentTitle,
                nodes: buffer
            )
            items.append(item)
            buffer.removeAll()
            currentTitle = nil
        }

        for node in nodes {
            if case .heading(let level, let text) = node {
                let lower = text.lowercased()
                let looksLikeQuestion =
                    lower.hasPrefix("question ") ||
                    lower.hasPrefix("q.") ||
                    lower.hasPrefix("q ")

                if level >= 2 && looksLikeQuestion {
                    flushBuffer()
                    qIndex += 1
                    currentTitle = text
                    buffer.append(node)
                    continue
                }
            }
            buffer.append(node)
        }

        flushBuffer()
        return items
    }

    /// Simple text search over this item.
    func matches(search query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return searchableText.localizedCaseInsensitiveContains(query)
    }
}

// MARK: - Private text flattener

private extension WorksheetItem {
    static func buildSearchText(from nodes: [Node]) -> String {
        var pieces: [String] = []

        for n in nodes {
            switch n {
            case .heading(_, let t):
                pieces.append(t)

            case .paragraph(let inlines):
                let s = inlines.compactMap { inline -> String? in
                    if case .text(let t) = inline { return t }
                    return nil
                }.joined(separator: " ")
                pieces.append(s)

            case .image(_, let alt):
                if let alt = alt { pieces.append(alt) }

            case .svgNode(_, let t, let desc):
                if let t = t { pieces.append(t) }
                if let first = desc?.first { pieces.append(first) }

            default:
                break
            }
        }

        return pieces.joined(separator: " ")
    }
}
