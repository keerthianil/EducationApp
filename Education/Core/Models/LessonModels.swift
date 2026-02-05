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

/// High-level blocks in the lesson – these are what the UI renders into
/// separate items: headings, paragraphs, images, SVGs, maps, etc.
enum Node: Codable, Identifiable {
    case heading(level: Int, text: String)
    case paragraph(items: [Inline])
    case image(src: String, alt: String?, shortDesc: String?)
    case svgNode(svg: String, title: String?, summaries: [String]?, shortDesc: [String]?, graphicData: [String: Any]?)
    case mapNode(json: String, title: String?, summaries: [String]?)
    case unknown

    /// We don't rely on identity across frames, so a random UUID per node is fine.
    var id: UUID {
        let contentString: String
        switch self {
        case .heading(let level, let text):
            contentString = "heading:\(level):\(text)"
        case .paragraph(let items):
            let itemsString = items.map { item in
                switch item {
                case .text(let t): return "text:\(t)"
                case .math(let latex, let mathml, let display):
                    return "math:\(latex ?? ""):\(mathml ?? ""):\(display ?? "")"
                case .unknown: return "unknown"
                }
            }.joined(separator: "|")
            contentString = "paragraph:\(itemsString)"
        case .image(let src, let alt, let shortDesc):
            contentString = "image:\(src):\(alt ?? ""):\(shortDesc ?? "")"
        case .svgNode(let svg, let title, let summaries, let shortDesc, let graphicData):
            let summariesStr = summaries?.joined(separator: "|") ?? ""
            let shortDescStr = shortDesc?.joined(separator: "|") ?? ""
            let graphicDataStr = graphicData != nil ? "hasGraphicData" : ""
            contentString = "svg:\(svg):\(title ?? ""):\(summariesStr):\(shortDescStr):\(graphicDataStr)"
        case .mapNode(let json, let title, let summaries):
            let summariesStr = summaries?.joined(separator: "|") ?? ""
            contentString = "map:\(json):\(title ?? ""):\(summariesStr)"
        case .unknown:
            contentString = "unknown"
        }
        return stableUUID(from: contentString)
    }
    
    /// Generate a stable UUID from a string hash
    private func stableUUID(from string: String) -> UUID {
        var hasher = Hasher()
        hasher.combine(string)
        let hash = hasher.finalize()
        // Convert hash to UUID format (8-4-4-4-12)
        let uuidString = String(format: "%08x-%04x-%04x-%04x-%012x",
                               UInt32(truncatingIfNeeded: hash) & 0xFFFFFFFF,
                               UInt16(truncatingIfNeeded: hash >> 32) & 0xFFFF,
                               UInt16(truncatingIfNeeded: (hash >> 48) & 0x0FFF) | 0x4000,
                               UInt16(truncatingIfNeeded: (hash >> 60) & 0x3FFF) | 0x8000,
                               UInt64(abs(Int64(hash))) % 1000000000000)
        return UUID(uuidString: uuidString) ?? UUID()
    }

    init(from decoder: Decoder) throws {
        // Not used – we parse via FlexibleLessonParser instead.
        self = .unknown
    }

    func encode(to encoder: Encoder) throws {
        // Not needed for this prototype.
    }
}

/// Inline content inside a paragraph: plain text or math runs.
enum Inline: Codable, Identifiable {
    case text(String)
    case math(latex: String?, mathml: String?, display: String?)
    case unknown

    var id: UUID { UUID() }

    init(from decoder: Decoder) throws { self = .unknown }
    func encode(to encoder: Encoder) throws {}
}

// MARK: - Flexible parser that tolerates multiple JSON shapes produced by converters

/// Central place that turns arbitrary lesson JSON into `[Node]`.
/// each sentence / equation / block is preserved as its own object.
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
            let keys = ["content", "nodes", "blocks", "elements", "items", "pageContent"]
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
            
            // Handle alt - can be string or array
            let alt: String?
            if let altArray = attrs?["alt"] as? [String] {
                alt = altArray.first
            } else {
                alt = attrs?["alt"] as? String
            }
            
            // Handle short_desc - can be string or array
            let shortDesc: String?
            if let shortDescArray = attrs?["short_desc"] as? [String] {
                shortDesc = shortDescArray.first
            } else {
                shortDesc = attrs?["short_desc"] as? String
            }
            
            return .image(src: src, alt: alt, shortDesc: shortDesc)
        }

        // SVG / graphics
        if rawType == "svgnode" || rawType == "svg" {
            let attrs = d["attrs"] as? [String: Any]
            let svg = (attrs?["svgContent"] as? String) ?? (attrs?["svg"] as? String) ?? ""
            let title = attrs?["title"] as? String
            
            // Handle both array and string formats for descriptions
            let long: [String]?
            if let longArray = attrs?["long_desc"] as? [String] {
                long = longArray
            } else if let longString = attrs?["long_desc"] as? String {
                long = [longString]
            } else {
                long = nil
            }
            
            let short: [String]?
            if let shortArray = attrs?["short_desc"] as? [String] {
                short = shortArray
            } else if let shortString = attrs?["short_desc"] as? String {
                short = [shortString]
            } else {
                short = nil
            }
            
            let summary: [String]?
            if let summaryArray = attrs?["summary"] as? [String] {
                summary = summaryArray
            } else if let summaryString = attrs?["summary"] as? String {
                summary = [summaryString]
            } else {
                summary = nil
            }
            
            // Extract graphicData if available (structured JSON with lines, vertices, labels)
            let graphicData = attrs?["graphicData"] as? [String: Any]
            
            // Use long_desc or summary for summaries, short_desc separately for VoiceOver
            return .svgNode(svg: svg, title: title, summaries: long ?? summary, shortDesc: short, graphicData: graphicData)
        }

        // Map / geographic graphics
        if rawType == "mapnode" || rawType == "map" {
            let attrs = d["attrs"] as? [String: Any]
            // Try to get JSON as string, or serialize if it's a dictionary
            let jsonString: String
            if let jsonStr = (attrs?["jsonContent"] as? String) ?? (attrs?["json"] as? String) {
                jsonString = jsonStr
            } else if let jsonDict = attrs?["jsonContent"] as? [String: Any] ?? attrs?["json"] as? [String: Any],
                      let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict),
                      let jsonStr = String(data: jsonData, encoding: .utf8) {
                jsonString = jsonStr
            } else {
                jsonString = ""
            }
            let title = attrs?["title"] as? String
            let long  = attrs?["long_desc"] as? [String]
            let short = attrs?["short_desc"] as? [String]
            let summary = attrs?["summary"] as? [String]
            return .mapNode(json: jsonString, title: title, summaries: long ?? summary ?? short)
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

// MARK: - A strict model some JSONs already use; converted to Node
//
//  NOTE: attrs is [String:String]. If the actual JSON uses numbers for some
//  attributes (like "level": 2), decoding this strict model might fail; in
//  that case we fall back to the FlexibleLessonParser above, so the app
//  still won't crash.

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
                let shortDesc = attrs?["short_desc"]
                return .image(src: src, alt: alt, shortDesc: shortDesc)

            case "svgNode":
                let svg = attrs?["svgContent"] ?? ""
                let title = attrs?["title"]
                let graphicData = attrs?["graphicData"] as? [String: Any]
                return .svgNode(svg: svg, title: title, summaries: nil, shortDesc: nil, graphicData: graphicData)

            case "mapNode", "map":
                let json = attrs?["jsonContent"] ?? attrs?["json"] ?? ""
                let title = attrs?["title"]
                return .mapNode(json: json, title: title, summaries: nil)

            default:
                return .unknown
            }
        }
    }
}