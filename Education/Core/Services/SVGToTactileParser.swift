//
//  SVGToTactileParser.swift
//  Education
//
//  Parses SVG content into tactile primitives for blind users

import Foundation
import SwiftUI

struct SVGToTactileParser {
    static func parse(svgContent: String, viewSize: CGSize) -> TactileScene {
        // SVG string from JSON may already be decoded, but handle escaping just in case
        // When JSON is decoded, \n becomes actual newline, so we don't need to replace "\\n"
        var unescapedSVG = svgContent
        
        // Remove any HTML encoding issues
        unescapedSVG = unescapedSVG.replacingOccurrences(of: "&quot;", with: "\"")
        unescapedSVG = unescapedSVG.replacingOccurrences(of: "&lt;", with: "<")
        unescapedSVG = unescapedSVG.replacingOccurrences(of: "&gt;", with: ">")
        
        // Extract SVG structure
        let viewBox = extractViewBox(from: unescapedSVG)
        
        // Parse XML elements - use dotall mode to match across newlines
        let rawLines = extractLineElements(from: unescapedSVG)
        let rawCircles = extractCircleElements(from: unescapedSVG)
        let rawTexts = extractTextElements(from: unescapedSVG)
        
        // Debug: Always log parsing results (not just in DEBUG)
        print("🔍 SVG Parser Results:")
        print("   Lines found: \(rawLines.count)")
        print("   Circles found: \(rawCircles.count)")
        print("   Texts found: \(rawTexts.count)")
        print("   ViewBox: \(viewBox)")
        print("   SVG length: \(unescapedSVG.count) chars")
        print("   SVG contains <line: \(unescapedSVG.contains("<line"))")
        print("   SVG contains <circle: \(unescapedSVG.contains("<circle"))")
        print("   SVG contains <text: \(unescapedSVG.contains("<text"))")
        if rawLines.isEmpty {
            print("   ⚠️ WARNING: No lines found!")
            print("   First 300 chars of SVG:")
            print(String(unescapedSVG.prefix(300)))
            
            // Try to find why parsing failed
            if let lineRange = unescapedSVG.range(of: "<line") {
                let startIndex = max(unescapedSVG.startIndex, unescapedSVG.index(lineRange.lowerBound, offsetBy: -20))
                let endIndex = min(unescapedSVG.endIndex, unescapedSVG.index(lineRange.lowerBound, offsetBy: 200))
                print("   Sample around <line tag:")
                print(String(unescapedSVG[startIndex..<endIndex]))
            }
        } else {
            print("   ✅ Successfully parsed \(rawLines.count) lines")
            if let firstLine = rawLines.first {
                print("   First line: id=\(firstLine.id), x1=\(firstLine.x1), y1=\(firstLine.y1), x2=\(firstLine.x2), y2=\(firstLine.y2)")
            }
        }
        
        // Create transform from viewBox to screen coordinates
        let transform = createTransform(from: viewBox, to: viewBox.size) // Will be applied later based on actual view size
        
        // Transform coordinates and remove duplicates
        var seenLines = Set<String>()
        let lines = rawLines.compactMap { line -> TactileLineSegment? in
            // Create a unique key for this line (normalize endpoints to avoid duplicates)
            let key = "\(min(line.x1, line.x2))_\(min(line.y1, line.y2))_\(max(line.x1, line.x2))_\(max(line.y1, line.y2))"
            if seenLines.contains(key) {
                print("⚠️ Skipping duplicate line: \(line.id)")
                return nil
            }
            seenLines.insert(key)
            
            return TactileLineSegment(
                id: line.id,
                start: line.start,
                end: line.end,
                strokeWidth: line.strokeWidth,
                associatedLabel: nil // Will be associated later
            )
        }
        
        let circles = rawCircles.map { circle in
            TactileVertex(
                id: circle.id,
                position: circle.center,
                connectedLineIds: [] // Will be populated during connectivity analysis
            )
        }
        
        let texts = rawTexts.map { text in
            TactileLabel(
                id: text.id,
                position: text.position,
                text: text.content,
                nearestLineId: nil // Will be associated later
            )
        }
        
        // Build connectivity graph
        let vertices = buildVertexGraph(lines: lines, circles: circles)
        
        // Find closed polygons
        let polygons = findClosedPolygons(lines: lines, vertices: vertices)
        
        // Associate labels with nearest lines and update line labels
        let labelsWithAssociations = associateLabelsWithLines(labels: texts, lines: lines)
        
        // Update lines with their associated labels
        let linesWithLabels = lines.map { line in
            // Find label associated with this line
            if let associatedLabel = labelsWithAssociations.first(where: { $0.nearestLineId == line.id }) {
                return TactileLineSegment(
                    id: line.id,
                    start: line.start,
                    end: line.end,
                    strokeWidth: line.strokeWidth,
                    associatedLabel: associatedLabel.text
                )
            }
            return line
        }
        
        return TactileScene(
            id: UUID().uuidString,
            lineSegments: linesWithLabels,
            polygons: polygons,
            vertices: vertices,
            labels: labelsWithAssociations,
            viewBox: viewBox,
            transform: transform,
            title: extractTitle(from: unescapedSVG),
            descriptions: extractDescriptions(from: unescapedSVG)
        )
    }
    
    // MARK: - ViewBox Extraction
    
    private static func extractViewBox(from svg: String) -> CGRect {
        // Look for viewBox="x y width height" in the SVG tag
        let svgTagPattern = #"<svg[^>]*>"#
        if let svgTagRange = svg.range(of: svgTagPattern, options: .regularExpression) {
            let svgTagContent = String(svg[svgTagRange])
            if let viewBoxValue = extractAttribute(from: svgTagContent, name: "viewBox") {
                // Parse "0 0 448 380" format - split by whitespace
                let numbers = viewBoxValue.split(whereSeparator: { $0.isWhitespace }).compactMap { Double($0) }
                if numbers.count >= 4 {
                    print("📐 Extracted viewBox: x=\(numbers[0]), y=\(numbers[1]), width=\(numbers[2]), height=\(numbers[3])")
                    return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
                } else {
                    print("⚠️ viewBox parse failed - got \(numbers.count) numbers from '\(viewBoxValue)'")
                }
            } else {
                print("⚠️ No viewBox attribute found in SVG tag")
            }
        }
        
        // Fallback: try width/height attributes
        let width = extractFloat(from: svg, pattern: #"width=["']([^"']+)["']"#) ?? 448
        let height = extractFloat(from: svg, pattern: #"height=["']([^"']+)["']"#) ?? 380
        
        print("📐 Using fallback viewBox: width=\(width), height=\(height)")
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
    
    private static func extractFloat(from string: String, pattern: String) -> CGFloat? {
        guard let match = string.range(of: pattern, options: .regularExpression) else { return nil }
        let matchedString = String(string[match])
        // Extract number from the matched string
        if let numberRange = matchedString.range(of: #"\d+\.?\d*"#, options: .regularExpression) {
            return Double(matchedString[numberRange]).map { CGFloat($0) }
        }
        return nil
    }
    
    // MARK: - Element Extraction
    
    private struct RawLine {
        let id: String
        let x1: CGFloat
        let y1: CGFloat
        let x2: CGFloat
        let y2: CGFloat
        let strokeWidth: CGFloat
        
        var start: CGPoint { CGPoint(x: x1, y: y1) }
        var end: CGPoint { CGPoint(x: x2, y: y2) }
    }
    
    private static func extractLineElements(from svg: String) -> [RawLine] {
        var lines: [RawLine] = []
        
        // Match self-closing <line> tags - handle whitespace before />
        // Pattern: <line ... /> or <line .../ > or <line ... / >
        // Use dotall to match across newlines
        let pattern = #"<line[^>]*?\s*/>"#
        
        let nsString = svg as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            print("⚠️ Failed to create regex for lines")
            return []
        }
        
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))
        
        print("🔍 Line regex matched \(matches.count) times")
        
        for match in matches {
            let lineString = nsString.substring(with: match.range)
            
            // Extract attributes
            let id = extractAttribute(from: lineString, name: "id") ?? "line_\(UUID().uuidString.prefix(8))"
            let x1 = CGFloat(Double(extractAttribute(from: lineString, name: "x1") ?? "0") ?? 0)
            let y1 = CGFloat(Double(extractAttribute(from: lineString, name: "y1") ?? "0") ?? 0)
            let x2 = CGFloat(Double(extractAttribute(from: lineString, name: "x2") ?? "0") ?? 0)
            let y2 = CGFloat(Double(extractAttribute(from: lineString, name: "y2") ?? "0") ?? 0)
            let strokeWidth = CGFloat(Double(extractAttribute(from: lineString, name: "stroke-width") ?? "1") ?? 1.0)
            
            lines.append(RawLine(id: id, x1: x1, y1: y1, x2: x2, y2: y2, strokeWidth: strokeWidth))
        }
        
        print("📏 Extracted \(lines.count) lines from SVG")
        if lines.count > 0 {
            print("   First line: id=\(lines[0].id), x1=\(lines[0].x1), y1=\(lines[0].y1), x2=\(lines[0].x2), y2=\(lines[0].y2)")
        }
        
        return lines
    }
    
    private static func extractAttribute(from string: String, name: String) -> String? {
        // Try with double quotes first: name="value"
        let doubleQuotePattern = #"#name="([^"]+)""#.replacingOccurrences(of: "#name", with: name)
        if let regex = try? NSRegularExpression(pattern: doubleQuotePattern, options: []) {
            let nsString = string as NSString
            if let match = regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: nsString.length)),
               match.numberOfRanges >= 2 {
                return nsString.substring(with: match.range(at: 1))
            }
        }
        
        // Try with single quotes: name='value'
        let singleQuotePattern = #"#name='([^']+)'"#.replacingOccurrences(of: "#name", with: name)
        if let regex = try? NSRegularExpression(pattern: singleQuotePattern, options: []) {
            let nsString = string as NSString
            if let match = regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: nsString.length)),
               match.numberOfRanges >= 2 {
                return nsString.substring(with: match.range(at: 1))
            }
        }
        
        // Try without quotes: name=value (for numeric values)
        let unquotedPattern = #"#name=([^\s>"]+)"#.replacingOccurrences(of: "#name", with: name)
        if let regex = try? NSRegularExpression(pattern: unquotedPattern, options: []) {
            let nsString = string as NSString
            if let match = regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: nsString.length)),
               match.numberOfRanges >= 2 {
                return nsString.substring(with: match.range(at: 1))
            }
        }
        
        return nil
    }
    
    private struct RawCircle {
        let id: String
        let cx: CGFloat
        let cy: CGFloat
        let r: CGFloat
        
        var center: CGPoint { CGPoint(x: cx, y: cy) }
    }
    
    private static func extractCircleElements(from svg: String) -> [RawCircle] {
        var circles: [RawCircle] = []
        // Match self-closing <circle> tags - handle whitespace before />
        let pattern = #"<circle[^>]*?\s*/>"#
        
        let nsString = svg as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            let circleString = nsString.substring(with: match.range)
            
            let id = extractAttribute(from: circleString, name: "id") ?? "circle_\(UUID().uuidString.prefix(8))"
            let cx = CGFloat(Double(extractAttribute(from: circleString, name: "cx") ?? "0") ?? 0)
            let cy = CGFloat(Double(extractAttribute(from: circleString, name: "cy") ?? "0") ?? 0)
            let r = CGFloat(Double(extractAttribute(from: circleString, name: "r") ?? "2") ?? 2)
            
            circles.append(RawCircle(id: id, cx: cx, cy: cy, r: r))
        }
        
        print("⭕ Extracted \(circles.count) circles from SVG")
        
        return circles
    }
    
    private struct RawText {
        let id: String
        let x: CGFloat
        let y: CGFloat
        let content: String
        
        var position: CGPoint { CGPoint(x: x, y: y) }
    }
    
    private static func extractTextElements(from svg: String) -> [RawText] {
        var texts: [RawText] = []
        // Match <text ...>content</text> - handle nested content and use dotall to match across newlines
        // Use a simpler pattern that matches text tags more reliably
        let pattern = #"<text([^>]*)>(.*?)</text>"#
        
        let nsString = svg as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            print("⚠️ Failed to create regex for text extraction")
            return []
        }
        
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))
        
        print("🔍 Text regex matched \(matches.count) times")
        
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            let fullMatch = nsString.substring(with: match.range(at: 0))
            let attributes = nsString.substring(with: match.range(at: 1))
            let rawContent = nsString.substring(with: match.range(at: 2))
            
            // Extract text content - remove any nested tags and get plain text
            var content = rawContent
            // Remove any nested XML tags (like <tspan>, etc.) recursively
            var previousContent = ""
            while previousContent != content {
                previousContent = content
                let tagPattern = #"<[^>]+>"#
                if let tagRegex = try? NSRegularExpression(pattern: tagPattern, options: []) {
                    content = tagRegex.stringByReplacingMatches(
                        in: content,
                        options: [],
                        range: NSRange(location: 0, length: (content as NSString).length),
                        withTemplate: ""
                    )
                }
            }
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Fix: If content is "0" and it's likely a period (common in SVG rendering issues)
            // Check if it's a single "0" character - it might actually be a period
            if content == "0" && content.count == 1 {
                // Check the context - if this is positioned near other text, it's likely a period
                // For now, we'll convert standalone "0" to "." when combining with numbers
                // We'll handle this in the combination logic instead
            }
            
            guard !content.isEmpty else { 
                print("   ⚠️ Skipping empty text element")
                continue 
            }
            
            let id = extractAttribute(from: fullMatch, name: "id") ?? "text_\(UUID().uuidString.prefix(8))"
            let x = CGFloat(Double(extractAttribute(from: fullMatch, name: "x") ?? "0") ?? 0)
            let y = CGFloat(Double(extractAttribute(from: fullMatch, name: "y") ?? "0") ?? 0)
            
            texts.append(RawText(id: id, x: x, y: y, content: content))
        }
        
        print("📝 Extracted \(texts.count) text elements from SVG")
        if texts.count > 0 {
            print("   First text: id=\(texts[0].id), x=\(texts[0].x), y=\(texts[0].y), content='\(texts[0].content)'")
            if texts.count > 1 {
                print("   Second text: id=\(texts[1].id), x=\(texts[1].x), y=\(texts[1].y), content='\(texts[1].content)'")
            }
        }
        
        return texts
    }
    
    // MARK: - Connectivity Analysis
    
    private static func buildVertexGraph(lines: [TactileLineSegment], circles: [TactileVertex]) -> [TactileVertex] {
        var vertices: [TactileVertex] = []
        let tolerance: CGFloat = 5.0
        
        // Start with circles (explicit vertices)
        vertices.append(contentsOf: circles)
        
        // Find line endpoints and intersections
        var allPoints: [CGPoint] = []
        for line in lines {
            allPoints.append(line.start)
            allPoints.append(line.end)
        }
        
        // Group nearby points into vertices
        var vertexMap: [String: [String]] = [:] // vertex ID -> line IDs
        
        for line in lines {
            // Find or create vertex for start point
            let startVertexId = findOrCreateVertex(
                at: line.start,
                existingVertices: &vertices,
                tolerance: tolerance
            )
            vertexMap[startVertexId, default: []].append(line.id)
            
            // Find or create vertex for end point
            let endVertexId = findOrCreateVertex(
                at: line.end,
                existingVertices: &vertices,
                tolerance: tolerance
            )
            vertexMap[endVertexId, default: []].append(line.id)
        }
        
        // Update vertices with connected lines
        return vertices.map { vertex in
            TactileVertex(
                id: vertex.id,
                position: vertex.position,
                connectedLineIds: vertexMap[vertex.id] ?? []
            )
        }
    }
    
    private static func findOrCreateVertex(
        at point: CGPoint,
        existingVertices: inout [TactileVertex],
        tolerance: CGFloat
    ) -> String {
        // Check if point is near existing vertex
        for vertex in existingVertices {
            let dx = abs(vertex.position.x - point.x)
            let dy = abs(vertex.position.y - point.y)
            if dx <= tolerance && dy <= tolerance {
                return vertex.id
            }
        }
        
        // Create new vertex
        let newVertex = TactileVertex(
            id: UUID().uuidString,
            position: point,
            connectedLineIds: []
        )
        existingVertices.append(newVertex)
        return newVertex.id
    }
    
    // MARK: - Polygon Detection
    
    private static func findClosedPolygons(
        lines: [TactileLineSegment],
        vertices: [TactileVertex]
    ) -> [TactilePolygon] {
        // For now, return empty - polygon detection is complex
        // Can be implemented later with cycle detection algorithm
        return []
    }
    
    // MARK: - Label Association
    
    private static func associateLabelsWithLines(
        labels: [TactileLabel],
        lines: [TactileLineSegment]
    ) -> [TactileLabel] {
        // First, combine nearby text labels that are likely parts of the same measurement
        let combinedLabels = combineNearbyTextLabels(labels: labels)
        
        return combinedLabels.map { label in
            // Find nearest line
            var nearestLineId: String?
            var minDistance = CGFloat.infinity
            
            for line in lines {
                let distance = line.distance(to: label.position)
                if distance < minDistance && distance < 50 { // Within 50 points
                    minDistance = distance
                    nearestLineId = line.id
                }
            }
            
            // Update line's associated label if this is the nearest label
            return TactileLabel(
                id: label.id,
                position: label.position,
                text: label.text,
                nearestLineId: nearestLineId
            )
        }
    }
    
    // Combine text labels that are very close together (likely parts of same measurement)
    // Smart combination: "35" + "0" = "350", "50" + "n" = "50n", but "IN" + "0" = "IN 0"
    private static func combineNearbyTextLabels(labels: [TactileLabel]) -> [TactileLabel] {
        var combined: [TactileLabel] = []
        var used = Set<String>()
        let proximityThreshold: CGFloat = 30.0 // Points - increased for better matching
        
        // Sort labels by x position to combine left-to-right
        let sortedLabels = labels.sorted { $0.position.x < $1.position.x }
        
        for label in sortedLabels {
            if used.contains(label.id) { continue }
            
            // Find nearby labels on the same line (similar y-coordinate)
            var nearbyLabels: [TactileLabel] = [label]
            var combinedText = label.text
            var combinedX = label.position.x
            var combinedY = label.position.y
            var count = 1
            
            // Look for labels to the right (higher x) that are on the same line
            for otherLabel in sortedLabels {
                if used.contains(otherLabel.id) || otherLabel.id == label.id { continue }
                
                let dx = otherLabel.position.x - label.position.x // Positive if to the right
                let dy = abs(otherLabel.position.y - label.position.y)
                
                // If labels are horizontally aligned (similar y) and close together horizontally
                // Only combine if the other label is to the right (dx > 0)
                if dy < 10 && dx > 0 && dx < proximityThreshold {
                    nearbyLabels.append(otherLabel)
                    
                    // Smart text combination:
                    // - If first is number and second is "0", treat "0" as ".": "35" + "0" = "35."
                    // - If both are numbers (and second is not "0"), combine: "35" + "5" = "355"
                    // - If first is number and second is letter, combine: "50" + "n" = "50n"
                    // - If first is letter and second is "0", treat "0" as ".": "IN" + "0" = "IN."
                    // - Otherwise: add space
                    let isFirstNumber = label.text.range(of: #"^\d+$"#, options: .regularExpression) != nil
                    let isSecondNumber = otherLabel.text.range(of: #"^\d+$"#, options: .regularExpression) != nil
                    let isSecondLetter = otherLabel.text.range(of: #"^[a-zA-Z]+$"#, options: .regularExpression) != nil
                    let isSecondZero = otherLabel.text == "0"
                    
                    if isFirstNumber && isSecondZero {
                        // Number + "0" (which is actually a period): "35" + "0" = "35."
                        combinedText += "."
                    } else if isFirstNumber && isSecondNumber {
                        // Both numbers (and second is not "0"): combine directly
                        combinedText += otherLabel.text
                    } else if isFirstNumber && isSecondLetter {
                        // Number + letter: combine directly
                        combinedText += otherLabel.text
                    } else if isSecondZero {
                        // Letter + "0" (which is actually a period): "IN" + "0" = "IN."
                        combinedText += "."
                    } else {
                        // Otherwise: add space
                        combinedText += " " + otherLabel.text
                    }
                    
                    combinedX += otherLabel.position.x
                    combinedY += otherLabel.position.y
                    count += 1
                    used.insert(otherLabel.id)
                }
            }
            
            if count > 1 {
                // Average position for combined label
                combinedX /= CGFloat(count)
                combinedY /= CGFloat(count)
                combined.append(TactileLabel(
                    id: label.id,
                    position: CGPoint(x: combinedX, y: combinedY),
                    text: combinedText,
                    nearestLineId: label.nearestLineId
                ))
            } else {
                combined.append(label)
            }
            
            used.insert(label.id)
        }
        
        return combined
    }
    
    // MARK: - Transform Creation
    
    private static func createTransform(from source: CGRect, to destination: CGSize) -> CGAffineTransform {
        let scaleX = destination.width / source.width
        let scaleY = destination.height / source.height
        return CGAffineTransform(scaleX: scaleX, y: scaleY)
    }
    
    // MARK: - Metadata Extraction
    
    private static func extractTitle(from svg: String) -> String? {
        // Extract from metadata JSON
        if let metadata = extractMetadataJSON(from: svg),
           let title = metadata["title"] as? String {
            return title
        }
        return nil
    }
    
    private static func extractDescriptions(from svg: String) -> [String]? {
        // Extract from metadata JSON
        if let metadata = extractMetadataJSON(from: svg) {
            if let longDesc = metadata["long_desc"] as? [String] {
                return longDesc
            }
            if let summary = metadata["summary"] as? [String] {
                return summary
            }
        }
        return nil
    }
    
    private static func extractMetadataJSON(from svg: String) -> [String: Any]? {
        let pattern = #"<metadata>([^<]+)</metadata>"#
        guard let match = svg.range(of: pattern, options: .regularExpression),
              let jsonData = String(svg[match]).range(of: #"\{.*\}"#, options: .regularExpression).map({ String(svg[$0]) })?.data(using: .utf8) else {
            return nil
        }
        
        return try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
    }
}

// MARK: - String Extension for Regex

extension String {
    func matches(of pattern: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsString = self as NSString
        let matches = regex.matches(in: self, options: [], range: NSRange(location: 0, length: nsString.length))
        return matches.compactMap { match in
            guard match.numberOfRanges > 0 else { return nil }
            return nsString.substring(with: match.range(at: 0))
        }
    }
}
