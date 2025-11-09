//
//  LessonModels.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation

struct LessonDocument: Codable {
    let type: String
    let content: [Node]
}

enum Node: Codable, Identifiable {
    case heading(level: Int, text: String)
    case paragraph(items: [Inline])
    case image(src: String, alt: String?)
    case svgNode(svg: String, title: String?, summaries: [String]?)
    case unknown

    var id: UUID { UUID() }

    enum CodingKeys: String, CodingKey { case type, attrs, content }

    struct HeadingAttrs: Codable { let level: Int? }
    struct ParagraphAttrs: Codable {}
    struct ImageAttrs: Codable { let src: String; let alt: String? }
    struct SVGAttrs: Codable {
        let svgContent: String
        let title: String?
        let summary: [String]?
        let short_desc: [String]?
        let long_desc: [String]?
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = (try? c.decode(String.self, forKey: .type)) ?? ""
        switch type {
        case "heading":
            let attrs = try? c.decode(HeadingAttrs.self, forKey: .attrs)
            let text = try Node.decodePlainText(from: c)
            self = .heading(level: attrs?.level ?? 1, text: text)
        case "paragraph":
            // Paragraph content may be text + inline math nodes
            let inlines = (try? c.decode([Inline].self, forKey: .content)) ?? []
            self = .paragraph(items: inlines)
        case "image":
            let attrs = try c.decode(ImageAttrs.self, forKey: .attrs)
            self = .image(src: attrs.src, alt: attrs.alt)
        case "svgNode":
            let attrs = try c.decode(SVGAttrs.self, forKey: .attrs)
            let desc = attrs.long_desc ?? attrs.summary ?? attrs.short_desc
            self = .svgNode(svg: attrs.svgContent, title: attrs.title, summaries: desc)
        default:
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws { /* not needed for now */ }

    private static func decodePlainText(from c: KeyedDecodingContainer<Node.CodingKeys>) throws -> String {
        let inlines = (try? c.decode([Inline].self, forKey: .content)) ?? []
        return inlines.compactMap { if case .text(let t) = $0 { return t } else { return nil } }.joined()
    }
}

enum Inline: Codable, Identifiable {
    case text(String)
    case math(latex: String?, mathml: String?, display: String?)
    case unknown

    var id: UUID { UUID() }

    enum CodingKeys: String, CodingKey { case type, text, attrs }

    struct MathAttrs: Codable { let latex: String?; let mathml: String?; let mathType: String? }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = (try? c.decode(String.self, forKey: .type)) ?? ""
        switch type {
        case "text":
            self = .text((try? c.decode(String.self, forKey: .text)) ?? "")
        case "math":
            let a = try? c.decode(MathAttrs.self, forKey: .attrs)
            self = .math(latex: a?.latex, mathml: a?.mathml, display: a?.mathType)
        default:
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws { /* not needed */ }
}
