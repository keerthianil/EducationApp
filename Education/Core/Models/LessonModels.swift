//
//  LessonModels.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation

/// A strict "document" shape some converters output: { "content": [nodes...] }
struct LessonDocument: Codable {
    let content: [Node]
}

/// High-level blocks in the lesson
enum Node: Codable, Identifiable {
    case heading(level: Int, text: String)
    case paragraph(items: [Inline])
    case image(src: String, alt: String?)
    case svgNode(svg: String, title: String?, summaries: [String]?)
    case unknown

    // FIXED: Store UUID instead of generating new one each access
    private static var uuidCache: [ObjectIdentifier: UUID] = [:]
    
    var id: String {
        // Generate stable ID based on content hash
        switch self {
        case .heading(let level, let text):
            return "heading_\(level)_\(text.hashValue)"
        case .paragraph(let items):
            return "paragraph_\(items.hashValue)"
        case .image(let src, _):
            return "image_\(src.hashValue)"
        case .svgNode(let svg, _, _):
            return "svg_\(svg.hashValue)"
        case .unknown:
            return "unknown_\(UUID().uuidString)"
        }
    }

    init(from decoder: Decoder) throws {
        self = .unknown
    }

    func encode(to encoder: Encoder) throws {
        // Not needed for this prototype.
    }
}

/// Inline content inside a paragraph: plain text or math runs.
enum Inline: Codable, Identifiable, Hashable {
    case text(String)
    case math(latex: String?, mathml: String?, display: String?)
    case unknown

    var id: String {
        switch self {
        case .text(let t):
            return "text_\(t.hashValue)"
        case .math(let latex, let mathml, _):
            return "math_\(latex?.hashValue ?? 0)_\(mathml?.hashValue ?? 0)"
        case .unknown:
            return "unknown_\(UUID().uuidString)"
        }
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        switch self {
        case .text(let t):
            hasher.combine("text")
            hasher.combine(t)
        case .math(let latex, let mathml, let display):
            hasher.combine("math")
            hasher.combine(latex)
            hasher.combine(mathml)
            hasher.combine(display)
        case .unknown:
            hasher.combine("unknown")
        }
    }
    
    static func == (lhs: Inline, rhs: Inline) -> Bool {
        switch (lhs, rhs) {
        case (.text(let l), .text(let r)):
            return l == r
        case (.math(let l1, let l2, let l3), .math(let r1, let r2, let r3)):
            return l1 == r1 && l2 == r2 && l3 == r3
        case (.unknown, .unknown):
            return true
        default:
            return false
        }
    }

    init(from decoder: Decoder) throws { self = .unknown }
    func encode(to encoder: Encoder) throws {}
}

// MARK: - Flexible parser that tolerates multiple JSON shapes produced by converters

enum FlexibleLessonParser {
    static func parseNodes(from data: Data) -> [Node] {
        // 1) Try the strict shape first
        if let doc = try? JSONDecoder().decode(LessonDocumentStrict.self, from: data) {
            return doc.content.map { $0.asNode() }
        }

        // 2) Fall back to tolerant dictionary parsing
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) else { return [] }
        return extractNodes(fromAny: obj)
    }

    private static func extractNodes(fromAny any: Any) -> [Node] {
        if let arr = any as? [[String: Any]] {
            return arr.compactMap(parseNodeDict)
        }
        if let dict = any as? [String: Any] {
            let keys = ["content", "nodes", "blocks", "elements", "items", "pageContent"]
            for k in keys {
                if let arr = dict[k] as? [[String: Any]] {
                    return arr.compactMap(parseNodeDict)
                }
            }
            if let pages = dict["pages"] as? [[String: Any]] {
                return pages.flatMap { extractNodes(fromAny: $0) }
            }
        }
        return []
    }

    private static func parseNodeDict(_ d: [String: Any]) -> Node? {
        let rawType = (d["type"] as? String)?.lowercased() ?? ""

        // Headings
        if rawType == "heading" || rawType == "h1" || rawType == "h2" || rawType == "h3" {
            let level = (d["attrs"] as? [String: Any])?["level"] as? Int
            let text = plainText(from: d)
            return .heading(level: level ?? levelFrom(rawType), text: text)
        }

        // Paragraphs
        if rawType == "paragraph" || rawType == "p" {
            let inlines = parseInlineArray(from: d)
            return .paragraph(items: inlines)
        }

        // Images
        if rawType == "image" || rawType == "img" {
            let attrs = d["attrs"] as? [String: Any]
            let src = (attrs?["src"] as? String) ?? ""
            // Handle alt as String or array (take first element if array)
            let alt: String?
            if let altString = attrs?["alt"] as? String {
                alt = altString
            } else if let altArray = attrs?["alt"] as? [String], let first = altArray.first {
                alt = first
            } else if let longDesc = attrs?["long_desc"] as? [String], let first = longDesc.first {
                alt = first
            } else if let shortDesc = attrs?["short_desc"] as? [String], let first = shortDesc.first {
                alt = first
            } else {
                alt = nil
            }
            return .image(src: src, alt: alt)
        }

        // SVG / graphics
        if rawType == "svgnode" || rawType == "svg" {
            let attrs = d["attrs"] as? [String: Any]
            let svg = (attrs?["svgContent"] as? String) ?? (attrs?["svg"] as? String) ?? ""
            let title = attrs?["title"] as? String
            let long  = attrs?["long_desc"] as? [String]
            let short = attrs?["short_desc"] as? [String]
            let summary = attrs?["summary"] as? [String]
            return .svgNode(svg: svg, title: title, summaries: long ?? summary ?? short)
        }

        // Unknown containers that still hold "content"
        if let content = d["content"] as? [[String: Any]], rawType.isEmpty == false {
            return .paragraph(items: content.compactMap(parseInlineDict))
        }

        return .unknown
    }

    private static func levelFrom(_ raw: String) -> Int {
        if raw == "h1" { return 1 }
        if raw == "h2" { return 2 }
        if raw == "h3" { return 3 }
        return 1
    }

    private static func plainText(from node: [String: Any]) -> String {
        if let content = node["content"] as? [[String: Any]] {
            return content.compactMap { $0["text"] as? String }.joined()
        }
        return (node["text"] as? String) ?? ""
    }

    private static func parseInlineArray(from node: [String: Any]) -> [Inline] {
        if let content = node["content"] as? [[String: Any]] {
            return content.compactMap(parseInlineDict)
        }
        if let t = node["text"] as? String { return [.text(t)] }
        return []
    }

    private static func parseInlineDict(_ d: [String: Any]) -> Inline? {
        let t = (d["type"] as? String)?.lowercased() ?? ""
        if t == "text" {
            return .text((d["text"] as? String) ?? "")
        }
        if t.contains("math") {
            let attrs = d["attrs"] as? [String: Any]
            let latex = (attrs?["latex"] as? String)
                ?? (d["latex"] as? String)
                ?? (attrs?["value"] as? String)
            let mathml = (attrs?["mathml"] as? String) ?? (d["mathml"] as? String)
            let mt = (attrs?["mathType"] as? String) ?? (d["mathType"] as? String)
            return .math(latex: latex, mathml: mathml, display: mt)
        }
        return .unknown
    }
}

// MARK: - Strict model

private struct LessonDocumentStrict: Codable {
    let content: [StrictNode]

    struct StrictNode: Codable {
        let type: String
        let attrs: [String: String]?
        let content: [StrictInline]?

        struct StrictInline: Codable {
            let type: String?
            let text: String?
            let attrs: [String: String]?
        }

        func asNode() -> Node {
            switch type {
            case "heading":
                let levelString = attrs?["level"] ?? ""
                let lvl = Int(levelString) ?? 1
                let txt = (content ?? []).compactMap { $0.text }.joined()
                return .heading(level: lvl, text: txt)

            case "paragraph":
                let inlines = (content ?? []).map { si -> Inline in
                    if let t = si.text { return .text(t) }
                    if let a = si.attrs {
                        return .math(
                            latex: a["latex"],
                            mathml: a["mathml"],
                            display: a["mathType"]
                        )
                    }
                    return .unknown
                }
                return .paragraph(items: inlines)

            case "image":
                let src = attrs?["src"] ?? ""
                let alt = attrs?["alt"]
                return .image(src: src, alt: alt)

            case "svgNode":
                let svg = attrs?["svgContent"] ?? ""
                let title = attrs?["title"]
                return .svgNode(svg: svg, title: title, summaries: nil)

            default:
                return .unknown
            }
        }
    }
}