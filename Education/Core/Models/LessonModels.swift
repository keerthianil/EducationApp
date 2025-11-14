//
//  LessonModels.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation

struct LessonDocument: Codable { let content: [Node] }

enum Node: Codable, Identifiable {
    case heading(level: Int, text: String)
    case paragraph(items: [Inline])
    case image(src: String, alt: String?)
    case svgNode(svg: String, title: String?, summaries: [String]?)
    case unknown
    var id: UUID { UUID() }

    init(from decoder: Decoder) throws {
        // Not used – we parse flexibly below.
        self = .unknown
    }
    func encode(to encoder: Encoder) throws {}
}

enum Inline: Codable, Identifiable {
    case text(String)
    case math(latex: String?, mathml: String?, display: String?)
    case unknown
    var id: UUID { UUID() }

    init(from decoder: Decoder) throws { self = .unknown }
    func encode(to encoder: Encoder) throws {}
}

// MARK: - Flexible parser that tolerates multiple JSON shapes produced by converters

enum FlexibleLessonParser {
    static func parseNodes(from data: Data) -> [Node] {
        // 1) Try the strict shape first (our original)
        if let doc = try? JSONDecoder().decode(LessonDocumentStrict.self, from: data) {
            return doc.content.map { $0.asNode() }
        }
        // 2) Fall back to tolerant dictionary parsing
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) else { return [] }
        return extractNodes(fromAny: obj)
    }

    // Accepts whole JSON (page, document, or array)
    private static func extractNodes(fromAny any: Any) -> [Node] {
        if let arr = any as? [[String: Any]] {
            return arr.compactMap(parseNodeDict)
        }
        if let dict = any as? [String: Any] {
            // common keys: content / nodes / blocks / elements / items / pageContent
            let keys = ["content","nodes","blocks","elements","items","pageContent"]
            for k in keys {
                if let arr = dict[k] as? [[String: Any]] {
                    return arr.compactMap(parseNodeDict)
                }
            }
            // sometimes each page lives under "pages": [ { content:[...] }, ...]
            if let pages = dict["pages"] as? [[String: Any]] {
                return pages.flatMap { extractNodes(fromAny: $0) }
            }
        }
        return []
    }

    // Convert one node dictionary into Node
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
            let alt = attrs?["alt"] as? String
            return .image(src: src, alt: alt)
        }
        // SVG / graphics
        if rawType == "svgnode" || rawType == "svg" {
            let attrs = d["attrs"] as? [String: Any]
            let svg = (attrs?["svgContent"] as? String) ?? (attrs?["svg"] as? String) ?? ""
            let title = attrs?["title"] as? String
            let long = attrs?["long_desc"] as? [String]
            let short = attrs?["short_desc"] as? [String]
            let summary = attrs?["summary"] as? [String]
            return .svgNode(svg: svg, title: title, summaries: long ?? summary ?? short)
        }
        // Unknown containers that still hold "content"
        if let content = d["content"] as? [[String: Any]], rawType.isEmpty == false {
            // treat it like a paragraph
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
        // fallback: paragraph has "text"
        if let t = node["text"] as? String { return [.text(t)] }
        return []
    }

    private static func parseInlineDict(_ d: [String: Any]) -> Inline? {
        let t = (d["type"] as? String)?.lowercased() ?? ""
        if t == "text" { return .text((d["text"] as? String) ?? "") }
        if t.contains("math") {
            let attrs = d["attrs"] as? [String: Any]
            let latex = (attrs?["latex"] as? String) ?? (d["latex"] as? String) ?? (attrs?["value"] as? String)
            let mathml = (attrs?["mathml"] as? String) ?? (d["mathml"] as? String)
            let mt = (attrs?["mathType"] as? String) ?? (d["mathType"] as? String)
            return .math(latex: latex, mathml: mathml, display: mt)
        }
        return .unknown
    }
}

// MARK: - A strict model some JSONs already use; converted to Node

private struct LessonDocumentStrict: Codable {
    let content: [StrictNode]
    struct StrictNode: Codable {
        let type: String
        let attrs: [String: StringOrInt]?
        let content: [StrictInline]?
        struct StrictInline: Codable {
            let type: String?
            let text: String?
            let attrs: [String: String]?
        }
        func asNode() -> Node {
            switch type {
            case "heading":
                let lvl = attrs?["level"]?.intValue ?? 1
                let txt = (content ?? []).compactMap { $0.text }.joined()
                return .heading(level: lvl, text: txt)
            case "paragraph":
                let inlines = (content ?? []).map { si -> Inline in
                    if let t = si.text { return .text(t) }
                    if let a = si.attrs {
                        return .math(latex: a["latex"], mathml: a["mathml"], display: a["mathType"])
                    }
                    return .unknown
                }
                return .paragraph(items: inlines)
            case "image":
                let src = attrs?["src"]?.stringValue ?? ""
                let alt = attrs?["alt"]?.stringValue
                return .image(src: src, alt: alt)
            case "svgNode":
                let svg = attrs?["svgContent"]?.stringValue ?? ""
                let title = attrs?["title"]?.stringValue
                return .svgNode(svg: svg, title: title, summaries: nil)
            default:
                return .unknown
            }
        }
    }
}

private enum StringOrInt: Codable {
    case s(String), i(Int)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Int.self) { self = .i(v) }
        else { self = .s(try c.decode(String.self)) }
    }
    var stringValue: String? { if case .s(let v) = self { return v } else { return nil } }
    var intValue: Int? { if case .i(let v) = self { return v } else { return nil } }
}


