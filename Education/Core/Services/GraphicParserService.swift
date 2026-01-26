//
//  GraphicParserService.swift
//  Education
//
//  Clean SVG parsing service that outputs JSON-serializable ParsedGraphic
//  Separates parsing logic from rendering for better maintainability

import Foundation
import SwiftUI

struct GraphicParserService {
    
    /// Parse SVG string into a clean ParsedGraphic model
    static func parse(svgContent: String) -> ParsedGraphic? {
        // Unescape HTML entities
        let unescapedSVG = svgContent
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
        
        // Extract viewBox
        guard let viewBox = extractViewBox(from: unescapedSVG) else {
            return nil
        }
        
        // Parse elements
        let lines = extractLines(from: unescapedSVG)
        let labels = extractAndPositionLabels(from: unescapedSVG, lines: lines)
        let vertices = extractVertices(from: unescapedSVG)
        
        // Extract title/description from metadata if available
        let (title, description) = extractMetadata(from: unescapedSVG)
        
        return ParsedGraphic(
            viewBox: ViewBox(
                x: viewBox.origin.x,
                y: viewBox.origin.y,
                width: viewBox.width,
                height: viewBox.height
            ),
            lines: lines,
            labels: labels,
            vertices: vertices,
            title: title,
            description: description
        )
    }
    
    // MARK: - ViewBox Extraction
    
    private static func extractViewBox(from svg: String) -> CGRect? {
        let pattern = #"viewBox\s*=\s*["']([^"']+)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: svg, range: NSRange(svg.startIndex..., in: svg)),
              let range = Range(match.range(at: 1), in: svg) else {
            return CGRect(x: 0, y: 0, width: 100, height: 100) // Default
        }
        
        let values = String(svg[range]).split(separator: " ").compactMap { Double($0) }
        guard values.count >= 4 else { return nil }
        
        return CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
    }
    
    // MARK: - Line Extraction
    
    private static func extractLines(from svg: String) -> [ParsedLine] {
        var lines: [ParsedLine] = []
        var lineIdCounter = 0
        
        // Extract <line> elements
        let linePattern = #"<line[^>]*x1\s*=\s*["']([^"']+)["'][^>]*y1\s*=\s*["']([^"']+)["'][^>]*x2\s*=\s*["']([^"']+)["'][^>]*y2\s*=\s*["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: linePattern, options: []) {
            let matches = regex.matches(in: svg, range: NSRange(svg.startIndex..., in: svg))
            for match in matches {
                guard match.numberOfRanges >= 5,
                      let x1Range = Range(match.range(at: 1), in: svg),
                      let y1Range = Range(match.range(at: 2), in: svg),
                      let x2Range = Range(match.range(at: 3), in: svg),
                      let y2Range = Range(match.range(at: 4), in: svg),
                      let x1 = Double(String(svg[x1Range])),
                      let y1 = Double(String(svg[y1Range])),
                      let x2 = Double(String(svg[x2Range])),
                      let y2 = Double(String(svg[y2Range])) else {
                    continue
                }
                
                let start = Point(x: x1, y: y1)
                let end = Point(x: x2, y: y2)
                let orientation = determineOrientation(start: start, end: end)
                
                lines.append(ParsedLine(
                    id: "line_\(lineIdCounter)",
                    start: start,
                    end: end,
                    strokeWidth: 2.0,
                    orientation: orientation
                ))
                lineIdCounter += 1
            }
        }
        
        return lines
    }
    
    private static func determineOrientation(start: Point, end: Point) -> ParsedLine.LineOrientation {
        let dx = abs(end.x - start.x)
        let dy = abs(end.y - start.y)
        
        if dy < 5 { // Nearly horizontal
            return .horizontal
        } else if dx < 5 { // Nearly vertical
            return .vertical
        } else {
            return .diagonal
        }
    }
    
    // MARK: - Label Extraction and Positioning
    
    private static func extractAndPositionLabels(from svg: String, lines: [ParsedLine]) -> [ParsedLabel] {
        var labels: [ParsedLabel] = []
        var labelIdCounter = 0
        
        // Extract <text> elements
        let textPattern = #"<text[^>]*x\s*=\s*["']([^"']+)["'][^>]*y\s*=\s*["']([^"']+)["'][^>]*>(.*?)</text>"#
        if let regex = try? NSRegularExpression(pattern: textPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: svg, range: NSRange(svg.startIndex..., in: svg))
            for match in matches {
                guard match.numberOfRanges >= 4,
                      let xRange = Range(match.range(at: 1), in: svg),
                      let yRange = Range(match.range(at: 2), in: svg),
                      let textRange = Range(match.range(at: 3), in: svg),
                      let x = Double(String(svg[xRange])),
                      let y = Double(String(svg[yRange])) else {
                    continue
                }
                
                let rawText = String(svg[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rawText.isEmpty else { continue }
                
                // Clean and combine text (simplified version)
                let cleanedText = cleanText(rawText)
                
                // Find nearest line
                let position = Point(x: x, y: y)
                let (nearestLineId, anchor) = findNearestLineAndAnchor(
                    position: position,
                    lines: lines
                )
                
                labels.append(ParsedLabel(
                    id: "label_\(labelIdCounter)",
                    text: cleanedText,
                    position: position,
                    nearestLineId: nearestLineId,
                    anchor: anchor
                ))
                labelIdCounter += 1
            }
        }
        
        // Combine nearby labels (number + unit)
        return combineNearbyLabels(labels)
    }
    
    private static func cleanText(_ text: String) -> String {
        // Basic cleaning: normalize whitespace, fix common OCR issues
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Fix "50n" -> "50 in"
        cleaned = cleaned.replacingOccurrences(
            of: #"(\d+)n\b"#,
            with: "$1 in",
            options: .regularExpression
        )
        
        // Normalize unit casing
        cleaned = cleaned.replacingOccurrences(of: " IN ", with: " in ", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: " FT ", with: " ft ", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: " YD ", with: " yd ", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: " IN", with: " in", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: " FT", with: " ft", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: " YD", with: " yd", options: .caseInsensitive)
        
        return cleaned
    }
    
    private static func findNearestLineAndAnchor(
        position: Point,
        lines: [ParsedLine]
    ) -> (lineId: String?, anchor: ParsedLabel.LabelAnchor) {
        var minDistance = CGFloat.infinity
        var nearestLineId: String?
        var anchor: ParsedLabel.LabelAnchor = .diagonal
        
        for line in lines {
            let distance = distanceToLine(point: position, line: line)
            if distance < minDistance && distance < 100 {
                minDistance = distance
                nearestLineId = line.id
                
                switch line.orientation {
                case .horizontal:
                    anchor = .above
                case .vertical:
                    anchor = .left
                case .diagonal:
                    anchor = .diagonal
                }
            }
        }
        
        return (nearestLineId, anchor)
    }
    
    private static func distanceToLine(point: Point, line: ParsedLine) -> CGFloat {
        let dx = line.end.x - line.start.x
        let dy = line.end.y - line.start.y
        let lengthSq = dx * dx + dy * dy
        
        guard lengthSq > 0 else {
            // Point-to-point distance
            let dx2 = point.x - line.start.x
            let dy2 = point.y - line.start.y
            return sqrt(dx2 * dx2 + dy2 * dy2)
        }
        
        // Project point onto line
        let t = max(0, min(1, ((point.x - line.start.x) * dx + (point.y - line.start.y) * dy) / lengthSq))
        let projX = line.start.x + t * dx
        let projY = line.start.y + t * dy
        
        // Distance from point to projection
        let dx2 = point.x - projX
        let dy2 = point.y - projY
        return sqrt(dx2 * dx2 + dy2 * dy2)
    }
    
    private static func combineNearbyLabels(_ labels: [ParsedLabel]) -> [ParsedLabel] {
        // Simple combining: if two labels are close and one is a number, the other is a unit, combine them
        var combined: [ParsedLabel] = []
        var used = Set<String>()
        
        for label in labels {
            if used.contains(label.id) { continue }
            
            // Look for nearby labels to combine
            var combinedText = label.text
            var combinedPosition = label.position
            var combinedAnchor = label.anchor
            var combinedLineId = label.nearestLineId
            
            for other in labels {
                if used.contains(other.id) || other.id == label.id { continue }
                
                let distance = sqrt(
                    pow(label.position.x - other.position.x, 2) +
                    pow(label.position.y - other.position.y, 2)
                )
                
                // If close enough and one is number, other is unit
                if distance < 50 {
                    let isNumber = label.text.range(of: #"^\d+"#, options: .regularExpression) != nil
                    let isUnit = ["in", "ft", "yd", "m", "cm"].contains { label.text.lowercased().contains($0) }
                    let otherIsNumber = other.text.range(of: #"^\d+"#, options: .regularExpression) != nil
                    let otherIsUnit = ["in", "ft", "yd", "m", "cm"].contains { other.text.lowercased().contains($0) }
                    
                    if (isNumber && otherIsUnit) || (isUnit && otherIsNumber) {
                        // Combine: number + unit
                        if isNumber {
                            combinedText = "\(label.text) \(other.text)"
                        } else {
                            combinedText = "\(other.text) \(label.text)"
                        }
                        // Use number's position
                        combinedPosition = isNumber ? label.position : other.position
                        combinedAnchor = label.anchor
                        combinedLineId = label.nearestLineId
                        used.insert(other.id)
                        break
                    }
                }
            }
            
            combined.append(ParsedLabel(
                id: label.id,
                text: combinedText,
                position: combinedPosition,
                nearestLineId: combinedLineId,
                anchor: combinedAnchor
            ))
            used.insert(label.id)
        }
        
        return combined
    }
    
    // MARK: - Vertex Extraction
    
    private static func extractVertices(from svg: String) -> [ParsedVertex] {
        var vertices: [ParsedVertex] = []
        var vertexIdCounter = 0
        
        // Extract <circle> elements (often used for vertices)
        let circlePattern = #"<circle[^>]*cx\s*=\s*["']([^"']+)["'][^>]*cy\s*=\s*["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: circlePattern, options: []) {
            let matches = regex.matches(in: svg, range: NSRange(svg.startIndex..., in: svg))
            for match in matches {
                guard match.numberOfRanges >= 3,
                      let cxRange = Range(match.range(at: 1), in: svg),
                      let cyRange = Range(match.range(at: 2), in: svg),
                      let cx = Double(String(svg[cxRange])),
                      let cy = Double(String(svg[cyRange])) else {
                    continue
                }
                
                vertices.append(ParsedVertex(
                    id: "vertex_\(vertexIdCounter)",
                    position: Point(x: cx, y: cy)
                ))
                vertexIdCounter += 1
            }
        }
        
        return vertices
    }
    
    // MARK: - Metadata Extraction
    
    private static func extractMetadata(from svg: String) -> (title: String?, description: String?) {
        var title: String?
        var description: String?
        
        // Extract <title>
        if let regex = try? NSRegularExpression(pattern: #"<title>(.*?)</title>"#, options: [.dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: svg, range: NSRange(svg.startIndex..., in: svg)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: svg) {
            title = String(svg[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Extract <desc>
        if let regex = try? NSRegularExpression(pattern: #"<desc>(.*?)</desc>"#, options: [.dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: svg, range: NSRange(svg.startIndex..., in: svg)),
           match.numberOfRanges > 1,
           let range = Range(match.range(at: 1), in: svg) {
            description = String(svg[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return (title, description)
    }
}

