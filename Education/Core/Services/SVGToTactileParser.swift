//
//  SVGToTactileParser.swift
//  Education
//
//  Parses SVG content into tactile primitives for blind users

import Foundation
import SwiftUI

struct SVGToTactileParser {

    #if DEBUG
    /// Debug logging for SVG parsing pipeline. Check Xcode console when running the app.
    static func debugLog(_ message: String) {
        print("[SVG-Parser] \(message)")
    }
    #else
    static func debugLog(_ message: String) {}
    #endif

    // MARK: - Cached Regex Patterns (compiled once for performance)
    
    private static let lineRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"<line[^>]*?(?:/>|></line>|>)"#, options: [.dotMatchesLineSeparators])
    }()
    
    private static let circleRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"<circle[^>]*?(?:/>|></circle>|>)"#, options: [.dotMatchesLineSeparators])
    }()
    
    private static let textRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"<text([^>]*)>(.*?)</text>"#, options: [.dotMatchesLineSeparators])
    }()
    
    private static let pathRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"<path[^>]*?(?:/>|></path>|>)"#, options: [.dotMatchesLineSeparators])
    }()
    
    private static let rectRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"<rect[^>]*?(?:/>|></rect>|>)"#, options: [.dotMatchesLineSeparators])
    }()
    
    private static let polygonRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"<polygon[^>]*?(?:/>|></polygon>|>)"#, options: [.dotMatchesLineSeparators])
    }()
    
    private static let polylineRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"<polyline[^>]*?(?:/>|></polyline>|>)"#, options: [.dotMatchesLineSeparators])
    }()
    
    private static let ellipseRegex: NSRegularExpression? = {
        try? NSRegularExpression(pattern: #"<ellipse[^>]*?(?:/>|></ellipse>|>)"#, options: [.dotMatchesLineSeparators])
    }()
    
    // MARK: - Main Parse Function
    
    /// Parse SVG and return ParsedGraphic (for caching as JSON)
    static func parseToParsedGraphic(svgContent: String) -> ParsedGraphic? {
        let scene = parse(svgContent: svgContent, viewSize: .zero)
        return ParsedGraphic.from(scene)
    }
    
    static func parse(svgContent: String, viewSize: CGSize) -> TactileScene {
        // Unescape HTML entities
        var unescapedSVG = svgContent
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#39;", with: "'")
        
        // Extract SVG structure
        let viewBox = extractViewBox(from: unescapedSVG)
        
        // Parse XML elements
        let rawLines = extractLineElements(from: unescapedSVG)
        let rawCircles = extractCircleElements(from: unescapedSVG)
        let rawTexts = extractTextElements(from: unescapedSVG)
        let pathLines = extractPathElements(from: unescapedSVG)
        let rectLines = extractRectElements(from: unescapedSVG)
        let polygonLines = extractPolygonElements(from: unescapedSVG)
        let polylineLines = extractPolylineElements(from: unescapedSVG)
        let ellipseCircles = extractEllipseElements(from: unescapedSVG)
        
        // Combine lines from all element types
        let allRawLines = rawLines + pathLines + rectLines + polygonLines + polylineLines
        
        // Combine circles and ellipses
        let allRawCircles = rawCircles + ellipseCircles
        
        // Debug logging
        #if DEBUG
        SVGToTactileParser.debugLog("🔍 SVG Parser Results:")
        SVGToTactileParser.debugLog("   ViewBox: \(viewBox)")
        SVGToTactileParser.debugLog("   Target Size: \(viewSize)")
        SVGToTactileParser.debugLog("   Lines from <line>: \(rawLines.count), <path>: \(pathLines.count), <rect>: \(rectLines.count), <polygon>: \(polygonLines.count), <polyline>: \(polylineLines.count)")
        SVGToTactileParser.debugLog("   Total lines: \(allRawLines.count), circles: \(allRawCircles.count), raw texts: \(rawTexts.count)")
        for (i, t) in rawTexts.enumerated() {
            SVGToTactileParser.debugLog("   RawText[\(i)] id=\(t.id) x=\(t.x) y=\(t.y) content=\"\(t.content)\"")
        }
        #endif
        
        // DON'T transform coordinates here - let the view handle transformation
        // This allows the view to properly scale and center based on actual canvas size
        
        // Deduplicate lines (using raw coordinates)
        var seenLines = Set<String>()
        let lines = allRawLines.compactMap { line -> TactileLineSegment? in
            // Skip very short lines (likely artifacts)
            let dx = line.end.x - line.start.x
            let dy = line.end.y - line.start.y
            let length = sqrt(dx * dx + dy * dy)
            if length < 2.0 {
                return nil
            }
            
            // Create a unique key (normalize to avoid duplicates regardless of direction)
            let minX = min(line.start.x, line.end.x)
            let minY = min(line.start.y, line.end.y)
            let maxX = max(line.start.x, line.end.x)
            let maxY = max(line.start.y, line.end.y)
            let key = String(format: "%.1f_%.1f_%.1f_%.1f", minX, minY, maxX, maxY)
            
            if seenLines.contains(key) {
                return nil
            }
            seenLines.insert(key)
            
            return TactileLineSegment(
                id: line.id,
                start: line.start,  // Use raw coordinates
                end: line.end,      // Use raw coordinates
                strokeWidth: line.strokeWidth,
                associatedLabel: nil
            )
        }
        
        // Use raw circle coordinates for vertices
        let circles = allRawCircles.enumerated().map { index, circle in
            return TactileVertex(
                id: circle.id,
                position: circle.center,  // Use raw coordinates
                connectedLineIds: [],
                vertexIndex: index + 1
            )
        }
        
        // Use raw text coordinates for labels
        let texts = rawTexts.map { text in
            return TactileLabel(
                id: text.id,
                position: text.position,  // Use raw coordinates
                text: text.content,
                nearestLineId: nil,
                estimatedSize: estimateTextSize(text.content)
            )
        }
        
        // Build connectivity graph
        let vertices = buildVertexGraph(lines: lines, circles: circles)
        
        // Find closed polygons
        let polygons = findClosedPolygons(lines: lines, vertices: vertices)
        
        // Combine nearby labels and associate with lines
        let combinedLabels = combineNearbyTextLabels(labels: texts)
        let labelsWithAssociations = associateLabelsWithLines(labels: combinedLabels, lines: lines)
        
        // Update lines with their associated labels
        let linesWithLabels = lines.map { line in
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
        
        #if DEBUG
        SVGToTactileParser.debugLog("✅ Parsing complete: lines=\(linesWithLabels.count) vertices=\(vertices.count) labels=\(labelsWithAssociations.count)")
        if labelsWithAssociations.isEmpty {
            SVGToTactileParser.debugLog("   ⚠️ ZERO labels will be drawn (all filtered or none extracted)")
        }
        for (i, lbl) in labelsWithAssociations.enumerated() {
            SVGToTactileParser.debugLog("   Label[\(i)] id=\(lbl.id) pos=(\(lbl.position.x),\(lbl.position.y)) text=\"\(lbl.text)\"")
        }
        #endif
        
        return TactileScene(
            id: UUID().uuidString,
            lineSegments: linesWithLabels,
            polygons: polygons,
            vertices: vertices,
            labels: labelsWithAssociations,
            viewBox: viewBox,
            transform: .identity,  // View handles transformation
            title: extractTitle(from: unescapedSVG),
            descriptions: extractDescriptions(from: unescapedSVG)
        )
    }
    
    // MARK: - Transform Helper
    
    private static func applyTransform(_ transform: CGAffineTransform, to point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x * transform.a + point.y * transform.c + transform.tx,
            y: point.x * transform.b + point.y * transform.d + transform.ty
        )
    }
    
    // MARK: - ViewBox Extraction
    
    private static func extractViewBox(from svg: String) -> CGRect {
        let nsString = svg as NSString
        
        // Look for viewBox attribute in SVG tag
        let svgTagPattern = #"<svg[^>]*>"#
        guard let svgTagRegex = try? NSRegularExpression(pattern: svgTagPattern, options: [.dotMatchesLineSeparators]),
              let svgMatch = svgTagRegex.firstMatch(in: svg, options: [], range: NSRange(location: 0, length: nsString.length)) else {
            return defaultViewBox(from: svg)
        }
        
        let svgTagContent = nsString.substring(with: svgMatch.range)
        
        if let viewBoxValue = extractAttribute(from: svgTagContent, name: "viewBox") {
            // Parse "0 0 448 380" format
            let numbers = viewBoxValue.split(whereSeparator: { $0.isWhitespace || $0 == "," })
                .compactMap { Double($0) }
            
            if numbers.count >= 4 {
                return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
            }
        }
        
        return defaultViewBox(from: svg)
    }
    
    private static func defaultViewBox(from svg: String) -> CGRect {
        // Fallback: try width/height attributes
        let width = extractNumericAttribute(from: svg, name: "width") ?? 448
        let height = extractNumericAttribute(from: svg, name: "height") ?? 380
        return CGRect(x: 0, y: 0, width: width, height: height)
    }
    
    private static func extractNumericAttribute(from string: String, name: String) -> CGFloat? {
        if let value = extractAttribute(from: string, name: name) {
            // Extract numeric part (handles "448", "448px", "100%")
            let numberPattern = #"[\d.]+"#
            if let regex = try? NSRegularExpression(pattern: numberPattern, options: []),
               let match = regex.firstMatch(in: value, options: [], range: NSRange(location: 0, length: (value as NSString).length)) {
                let numberString = (value as NSString).substring(with: match.range)
                return Double(numberString).map { CGFloat($0) }
            }
        }
        return nil
    }
    
    // MARK: - Raw Element Structures
    
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
    
    private struct RawCircle {
        let id: String
        let cx: CGFloat
        let cy: CGFloat
        let r: CGFloat
        
        var center: CGPoint { CGPoint(x: cx, y: cy) }
    }
    
    private struct RawText {
        let id: String
        let x: CGFloat
        let y: CGFloat
        let content: String
        let fontSize: CGFloat
        
        var position: CGPoint { CGPoint(x: x, y: y) }
    }
    
    // MARK: - Element Extraction
    
    private static func extractLineElements(from svg: String) -> [RawLine] {
        var lines: [RawLine] = []
        let nsString = svg as NSString
        
        guard let regex = lineRegex else { return [] }
        
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for (index, match) in matches.enumerated() {
            let lineString = nsString.substring(with: match.range)
            
            let id = extractAttribute(from: lineString, name: "id") ?? "line_\(index)"
            let x1 = CGFloat(Double(extractAttribute(from: lineString, name: "x1") ?? "0") ?? 0)
            let y1 = CGFloat(Double(extractAttribute(from: lineString, name: "y1") ?? "0") ?? 0)
            let x2 = CGFloat(Double(extractAttribute(from: lineString, name: "x2") ?? "0") ?? 0)
            let y2 = CGFloat(Double(extractAttribute(from: lineString, name: "y2") ?? "0") ?? 0)
            let strokeWidth = CGFloat(Double(extractAttribute(from: lineString, name: "stroke-width") ?? "1") ?? 1.0)
            
            // Skip zero-length lines
            if abs(x1 - x2) < 0.1 && abs(y1 - y2) < 0.1 {
                continue
            }
            
            lines.append(RawLine(id: id, x1: x1, y1: y1, x2: x2, y2: y2, strokeWidth: strokeWidth))
        }
        
        return lines
    }
    
    private static func extractCircleElements(from svg: String) -> [RawCircle] {
        var circles: [RawCircle] = []
        let nsString = svg as NSString
        
        guard let regex = circleRegex else { return [] }
        
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for (index, match) in matches.enumerated() {
            let circleString = nsString.substring(with: match.range)
            
            let id = extractAttribute(from: circleString, name: "id") ?? "circle_\(index)"
            let cx = CGFloat(Double(extractAttribute(from: circleString, name: "cx") ?? "0") ?? 0)
            let cy = CGFloat(Double(extractAttribute(from: circleString, name: "cy") ?? "0") ?? 0)
            let r = CGFloat(Double(extractAttribute(from: circleString, name: "r") ?? "2") ?? 2)
            
            circles.append(RawCircle(id: id, cx: cx, cy: cy, r: r))
        }
        
        return circles
    }
    
    private static func extractTextElements(from svg: String) -> [RawText] {
        var texts: [RawText] = []
        let nsString = svg as NSString
        
        guard let regex = textRegex else { return [] }
        
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for (index, match) in matches.enumerated() {
            guard match.numberOfRanges >= 3 else { continue }
            
            let fullMatch = nsString.substring(with: match.range)
            let rawContent = nsString.substring(with: match.range(at: 2))
            
            // Clean content: remove nested tags, trim whitespace
            var content = rawContent
            
            // Remove nested XML tags
            if let tagRegex = try? NSRegularExpression(pattern: #"<[^>]+>"#, options: []) {
                content = tagRegex.stringByReplacingMatches(
                    in: content,
                    options: [],
                    range: NSRange(location: 0, length: (content as NSString).length),
                    withTemplate: ""
                )
            }
            
            content = content.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty content
            guard !content.isEmpty else { continue }
            
            let id = extractAttribute(from: fullMatch, name: "id") ?? "text_\(index)"
            let x = CGFloat(Double(extractAttribute(from: fullMatch, name: "x") ?? "0") ?? 0)
            let y = CGFloat(Double(extractAttribute(from: fullMatch, name: "y") ?? "0") ?? 0)
            let fontSize = CGFloat(Double(extractAttribute(from: fullMatch, name: "font-size")?.replacingOccurrences(of: "px", with: "") ?? "15") ?? 15)
            
            texts.append(RawText(id: id, x: x, y: y, content: content, fontSize: fontSize))
        }
        
        return texts
    }
    
    private static func extractPathElements(from svg: String) -> [RawLine] {
        var lines: [RawLine] = []
        let nsString = svg as NSString
        
        guard let regex = pathRegex else { return [] }
        
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for (pathIndex, match) in matches.enumerated() {
            let pathString = nsString.substring(with: match.range)
            
            guard let d = extractAttribute(from: pathString, name: "d") else { continue }
            let strokeWidth = CGFloat(Double(extractAttribute(from: pathString, name: "stroke-width") ?? "1") ?? 1.0)
            
            // Parse path commands
            let pathLines = parsePathData(d, strokeWidth: strokeWidth, pathIndex: pathIndex)
            lines.append(contentsOf: pathLines)
        }
        
        return lines
    }
    
    private static func parsePathData(_ d: String, strokeWidth: CGFloat, pathIndex: Int) -> [RawLine] {
        var lines: [RawLine] = []
        var currentPoint = CGPoint.zero
        var startPoint = CGPoint.zero
        var lineIndex = 0
        
        // Tokenize path data
        let commandPattern = #"([MmLlHhVvZzCcSsQqTtAa])([^MmLlHhVvZzCcSsQqTtAa]*)"#
        guard let regex = try? NSRegularExpression(pattern: commandPattern, options: []) else {
            return []
        }
        
        let nsD = d as NSString
        let matches = regex.matches(in: d, options: [], range: NSRange(location: 0, length: nsD.length))
        
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            
            let command = nsD.substring(with: match.range(at: 1))
            let argsString = nsD.substring(with: match.range(at: 2))
            
            // Parse numbers from args
            let numberPattern = #"-?[\d.]+(?:e[+-]?\d+)?"#
            guard let numRegex = try? NSRegularExpression(pattern: numberPattern, options: [.caseInsensitive]) else {
                continue
            }
            
            let numMatches = numRegex.matches(in: argsString, options: [], range: NSRange(location: 0, length: (argsString as NSString).length))
            let numbers = numMatches.compactMap { Double((argsString as NSString).substring(with: $0.range)) }.map { CGFloat($0) }
            
            switch command {
            case "M": // Absolute moveto
                if numbers.count >= 2 {
                    currentPoint = CGPoint(x: numbers[0], y: numbers[1])
                    startPoint = currentPoint
                }
                
            case "m": // Relative moveto
                if numbers.count >= 2 {
                    currentPoint = CGPoint(x: currentPoint.x + numbers[0], y: currentPoint.y + numbers[1])
                    startPoint = currentPoint
                }
                
            case "L": // Absolute lineto
                var i = 0
                while i + 1 < numbers.count {
                    let endPoint = CGPoint(x: numbers[i], y: numbers[i + 1])
                    lines.append(RawLine(
                        id: "path_\(pathIndex)_line_\(lineIndex)",
                        x1: currentPoint.x, y1: currentPoint.y,
                        x2: endPoint.x, y2: endPoint.y,
                        strokeWidth: strokeWidth
                    ))
                    currentPoint = endPoint
                    lineIndex += 1
                    i += 2
                }
                
            case "l": // Relative lineto
                var i = 0
                while i + 1 < numbers.count {
                    let endPoint = CGPoint(x: currentPoint.x + numbers[i], y: currentPoint.y + numbers[i + 1])
                    lines.append(RawLine(
                        id: "path_\(pathIndex)_line_\(lineIndex)",
                        x1: currentPoint.x, y1: currentPoint.y,
                        x2: endPoint.x, y2: endPoint.y,
                        strokeWidth: strokeWidth
                    ))
                    currentPoint = endPoint
                    lineIndex += 1
                    i += 2
                }
                
            case "H": // Absolute horizontal lineto
                for num in numbers {
                    let endPoint = CGPoint(x: num, y: currentPoint.y)
                    lines.append(RawLine(
                        id: "path_\(pathIndex)_line_\(lineIndex)",
                        x1: currentPoint.x, y1: currentPoint.y,
                        x2: endPoint.x, y2: endPoint.y,
                        strokeWidth: strokeWidth
                    ))
                    currentPoint = endPoint
                    lineIndex += 1
                }
                
            case "h": // Relative horizontal lineto
                for num in numbers {
                    let endPoint = CGPoint(x: currentPoint.x + num, y: currentPoint.y)
                    lines.append(RawLine(
                        id: "path_\(pathIndex)_line_\(lineIndex)",
                        x1: currentPoint.x, y1: currentPoint.y,
                        x2: endPoint.x, y2: endPoint.y,
                        strokeWidth: strokeWidth
                    ))
                    currentPoint = endPoint
                    lineIndex += 1
                }
                
            case "V": // Absolute vertical lineto
                for num in numbers {
                    let endPoint = CGPoint(x: currentPoint.x, y: num)
                    lines.append(RawLine(
                        id: "path_\(pathIndex)_line_\(lineIndex)",
                        x1: currentPoint.x, y1: currentPoint.y,
                        x2: endPoint.x, y2: endPoint.y,
                        strokeWidth: strokeWidth
                    ))
                    currentPoint = endPoint
                    lineIndex += 1
                }
                
            case "v": // Relative vertical lineto
                for num in numbers {
                    let endPoint = CGPoint(x: currentPoint.x, y: currentPoint.y + num)
                    lines.append(RawLine(
                        id: "path_\(pathIndex)_line_\(lineIndex)",
                        x1: currentPoint.x, y1: currentPoint.y,
                        x2: endPoint.x, y2: endPoint.y,
                        strokeWidth: strokeWidth
                    ))
                    currentPoint = endPoint
                    lineIndex += 1
                }
                
            case "Z", "z": // Close path
                let dx = currentPoint.x - startPoint.x
                let dy = currentPoint.y - startPoint.y
                if sqrt(dx*dx + dy*dy) > 1.0 {
                    lines.append(RawLine(
                        id: "path_\(pathIndex)_line_\(lineIndex)",
                        x1: currentPoint.x, y1: currentPoint.y,
                        x2: startPoint.x, y2: startPoint.y,
                        strokeWidth: strokeWidth
                    ))
                    lineIndex += 1
                }
                currentPoint = startPoint
                
            default:
                // Skip curves (C, S, Q, T, A) - could approximate with line segments
                break
            }
        }
        
        return lines
    }
    
    // MARK: - Rect Element Extraction
    
    private static func extractRectElements(from svg: String) -> [RawLine] {
        var lines: [RawLine] = []
        let nsString = svg as NSString
        
        guard let regex = rectRegex else { return [] }
        
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for (rectIndex, match) in matches.enumerated() {
            let rectString = nsString.substring(with: match.range)
            
            let x = CGFloat(Double(extractAttribute(from: rectString, name: "x") ?? "0") ?? 0)
            let y = CGFloat(Double(extractAttribute(from: rectString, name: "y") ?? "0") ?? 0)
            let width = CGFloat(Double(extractAttribute(from: rectString, name: "width") ?? "0") ?? 0)
            let height = CGFloat(Double(extractAttribute(from: rectString, name: "height") ?? "0") ?? 0)
            let strokeWidth = CGFloat(Double(extractAttribute(from: rectString, name: "stroke-width") ?? "1") ?? 1.0)
            
            guard width > 0 && height > 0 else { continue }
            
            // Create 4 lines for the rectangle
            let topLeft = CGPoint(x: x, y: y)
            let topRight = CGPoint(x: x + width, y: y)
            let bottomRight = CGPoint(x: x + width, y: y + height)
            let bottomLeft = CGPoint(x: x, y: y + height)
            
            lines.append(RawLine(id: "rect_\(rectIndex)_top", x1: topLeft.x, y1: topLeft.y, x2: topRight.x, y2: topRight.y, strokeWidth: strokeWidth))
            lines.append(RawLine(id: "rect_\(rectIndex)_right", x1: topRight.x, y1: topRight.y, x2: bottomRight.x, y2: bottomRight.y, strokeWidth: strokeWidth))
            lines.append(RawLine(id: "rect_\(rectIndex)_bottom", x1: bottomRight.x, y1: bottomRight.y, x2: bottomLeft.x, y2: bottomLeft.y, strokeWidth: strokeWidth))
            lines.append(RawLine(id: "rect_\(rectIndex)_left", x1: bottomLeft.x, y1: bottomLeft.y, x2: topLeft.x, y2: topLeft.y, strokeWidth: strokeWidth))
        }
        
        return lines
    }
    
    // MARK: - Polygon Element Extraction
    
    private static func extractPolygonElements(from svg: String) -> [RawLine] {
        var lines: [RawLine] = []
        let nsString = svg as NSString
        
        guard let regex = polygonRegex else { return [] }
        
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for (polygonIndex, match) in matches.enumerated() {
            let polygonString = nsString.substring(with: match.range)
            
            guard let pointsStr = extractAttribute(from: polygonString, name: "points") else { continue }
            let strokeWidth = CGFloat(Double(extractAttribute(from: polygonString, name: "stroke-width") ?? "1") ?? 1.0)
            
            let points = parsePointsList(pointsStr)
            guard points.count >= 2 else { continue }
            
            // Create lines connecting all points (closed polygon)
            for i in 0..<points.count {
                let start = points[i]
                let end = points[(i + 1) % points.count]
                lines.append(RawLine(
                    id: "polygon_\(polygonIndex)_line_\(i)",
                    x1: start.x, y1: start.y,
                    x2: end.x, y2: end.y,
                    strokeWidth: strokeWidth
                ))
            }
        }
        
        return lines
    }
    
    // MARK: - Polyline Element Extraction
    
    private static func extractPolylineElements(from svg: String) -> [RawLine] {
        var lines: [RawLine] = []
        let nsString = svg as NSString
        
        guard let regex = polylineRegex else { return [] }
        
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for (polylineIndex, match) in matches.enumerated() {
            let polylineString = nsString.substring(with: match.range)
            
            guard let pointsStr = extractAttribute(from: polylineString, name: "points") else { continue }
            let strokeWidth = CGFloat(Double(extractAttribute(from: polylineString, name: "stroke-width") ?? "1") ?? 1.0)
            
            let points = parsePointsList(pointsStr)
            guard points.count >= 2 else { continue }
            
            // Create lines connecting all points (open polyline - not closed)
            for i in 0..<(points.count - 1) {
                let start = points[i]
                let end = points[i + 1]
                lines.append(RawLine(
                    id: "polyline_\(polylineIndex)_line_\(i)",
                    x1: start.x, y1: start.y,
                    x2: end.x, y2: end.y,
                    strokeWidth: strokeWidth
                ))
            }
        }
        
        return lines
    }
    
    // MARK: - Ellipse Element Extraction
    
    private static func extractEllipseElements(from svg: String) -> [RawCircle] {
        var circles: [RawCircle] = []
        let nsString = svg as NSString
        
        guard let regex = ellipseRegex else { return [] }
        
        let matches = regex.matches(in: svg, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for (index, match) in matches.enumerated() {
            let ellipseString = nsString.substring(with: match.range)
            
            let id = extractAttribute(from: ellipseString, name: "id") ?? "ellipse_\(index)"
            let cx = CGFloat(Double(extractAttribute(from: ellipseString, name: "cx") ?? "0") ?? 0)
            let cy = CGFloat(Double(extractAttribute(from: ellipseString, name: "cy") ?? "0") ?? 0)
            let rx = CGFloat(Double(extractAttribute(from: ellipseString, name: "rx") ?? "2") ?? 2)
            let ry = CGFloat(Double(extractAttribute(from: ellipseString, name: "ry") ?? "2") ?? 2)
            
            // Use average radius for hit testing
            let r = (rx + ry) / 2
            
            circles.append(RawCircle(id: id, cx: cx, cy: cy, r: r))
        }
        
        return circles
    }
    
    // MARK: - Helper: Parse Points List
    
    private static func parsePointsList(_ pointsStr: String) -> [CGPoint] {
        var points: [CGPoint] = []
        
        // Points can be: "x1,y1 x2,y2" or "x1 y1 x2 y2" or "x1,y1,x2,y2"
        let numberPattern = #"-?[\d.]+(?:e[+-]?\d+)?"#
        guard let numRegex = try? NSRegularExpression(pattern: numberPattern, options: [.caseInsensitive]) else {
            return []
        }
        
        let nsString = pointsStr as NSString
        let numMatches = numRegex.matches(in: pointsStr, options: [], range: NSRange(location: 0, length: nsString.length))
        let numbers = numMatches.compactMap { Double(nsString.substring(with: $0.range)) }.map { CGFloat($0) }
        
        // Pair up numbers as x,y coordinates
        var i = 0
        while i + 1 < numbers.count {
            points.append(CGPoint(x: numbers[i], y: numbers[i + 1]))
            i += 2
        }
        
        return points
    }
    
    // MARK: - Attribute Extraction
    
    private static func extractAttribute(from string: String, name: String) -> String? {
        // Try double quotes: name="value"
        let doubleQuotePattern = "\(name)=\"([^\"]*)\""
        if let regex = try? NSRegularExpression(pattern: doubleQuotePattern, options: []) {
            let nsString = string as NSString
            if let match = regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: nsString.length)),
               match.numberOfRanges >= 2 {
                return nsString.substring(with: match.range(at: 1))
            }
        }
        
        // Try single quotes: name='value'
        let singleQuotePattern = "\(name)='([^']*)'"
        if let regex = try? NSRegularExpression(pattern: singleQuotePattern, options: []) {
            let nsString = string as NSString
            if let match = regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: nsString.length)),
               match.numberOfRanges >= 2 {
                return nsString.substring(with: match.range(at: 1))
            }
        }
        
        return nil
    }
    
    // MARK: - Text Processing
    
    private static func estimateTextSize(_ text: String) -> CGSize {
        // Rough estimate: ~8 points per character width, 15 points height
        let width = CGFloat(text.count) * 8.0
        let height: CGFloat = 15.0
        return CGSize(width: max(width, 20), height: height)
    }
    
    private static func combineNearbyTextLabels(labels: [TactileLabel]) -> [TactileLabel] {
        guard !labels.isEmpty else {
            #if DEBUG
            SVGToTactileParser.debugLog("   [Combine] No labels to combine")
            #endif
            return []
        }
        #if DEBUG
        SVGToTactileParser.debugLog("   [Combine] Input \(labels.count) labels")
        #endif
        var combined: [TactileLabel] = []
        var used = Set<String>()
        
        // Horizontal proximity threshold
        let horizontalThreshold: CGFloat = 50.0
        // Vertical alignment threshold (must be on same line)
        let verticalThreshold: CGFloat = 12.0
        // Relaxed thresholds when pairing unit with number (e.g. "35" + "in.")
        let verticalThresholdUnit: CGFloat = 50.0
        let horizontalThresholdUnit: CGFloat = 65.0
        
        // Sort by position (top-to-bottom, left-to-right)
        let sortedLabels = labels.sorted { a, b in
            if abs(a.position.y - b.position.y) < verticalThreshold {
                return a.position.x < b.position.x
            }
            return a.position.y < b.position.y
        }
        
        func verticalOK(_ a: TactileLabel, _ b: TactileLabel, dy: CGFloat) -> Bool {
            let useRelaxed = isUnitOnly(a.text) || isUnitOnly(b.text)
            return dy < (useRelaxed ? verticalThresholdUnit : verticalThreshold)
        }
        
        func horizontalOK(_ a: TactileLabel, _ b: TactileLabel, dx: CGFloat, isRight: Bool) -> Bool {
            let useRelaxed = isUnitOnly(a.text) || isUnitOnly(b.text)
            let limit = useRelaxed ? horizontalThresholdUnit : horizontalThreshold
            return isRight ? (dx > 0 && dx < limit) : (dx < 0 && dx > -limit)
        }
        
        for label in sortedLabels {
            if used.contains(label.id) { continue }
            
            var combinedText = label.text
            var combinedX = label.position.x
            var combinedY = label.position.y
            var count: CGFloat = 1
            // Track the primary position (number's ORIGINAL position when combining number+unit)
            // Don't update this when combining with noise like "0" - only for meaningful combinations
            var primaryX = label.position.x
            var primaryY = label.position.y
            var isPrimaryNumber = isNumberOnly(label.text)
            #if DEBUG
            SVGToTactileParser.debugLog("   [Combine] START: id=\(label.id) text=\"\(label.text)\" pos=(\(label.position.x),\(label.position.y)) primary=(\(primaryX),\(primaryY)) isNum=\(isPrimaryNumber)")
            #endif
            
            // Find labels to the LEFT (e.g. "in" left of "35" -> "35 in")
            let leftLabels = sortedLabels.filter { other in
                guard !used.contains(other.id), other.id != label.id else { return false }
                let dx = other.position.x - label.position.x
                let dy = abs(other.position.y - label.position.y)
                return horizontalOK(label, other, dx: dx, isRight: false) && verticalOK(label, other, dy: dy)
            }.sorted { $0.position.x > $1.position.x } // rightmost-left first
            
            for otherLabel in leftLabels {
                let newText = smartCombineText(otherLabel.text, combinedText)
                combinedText = newText
                combinedX += otherLabel.position.x
                combinedY += otherLabel.position.y
                count += 1
                // Only update primary position if combining with a meaningful label (not "0" noise)
                if otherLabel.text.trimmingCharacters(in: .whitespaces) != "0" {
                    // For number+unit, keep the number's position
                    if isPrimaryNumber && isUnitOnly(otherLabel.text) {
                        // Keep primary position (number's position)
                        #if DEBUG
                        SVGToTactileParser.debugLog("   [Combine] LEFT: \"\(otherLabel.text)\" + \"\(combinedText)\" -> keep primary=(\(primaryX),\(primaryY))")
                        #endif
                    } else if isUnitOnly(combinedText) && isNumberOnly(otherLabel.text) {
                        // Unit + number: use number's position
                        primaryX = otherLabel.position.x
                        primaryY = otherLabel.position.y
                        isPrimaryNumber = true
                        #if DEBUG
                        SVGToTactileParser.debugLog("   [Combine] LEFT: unit + \"\(otherLabel.text)\" -> primary=(\(primaryX),\(primaryY))")
                        #endif
                    }
                } else {
                    #if DEBUG
                    SVGToTactileParser.debugLog("   [Combine] LEFT: skipping \"0\" noise, primary stays=(\(primaryX),\(primaryY))")
                    #endif
                }
                used.insert(otherLabel.id)
            }
            
            // Find labels to the right (e.g. "35" + "in." -> "35 in.")
            for otherLabel in sortedLabels {
                if used.contains(otherLabel.id) || otherLabel.id == label.id { continue }
                
                let dx = otherLabel.position.x - label.position.x
                let dy = abs(otherLabel.position.y - label.position.y)
                
                if horizontalOK(label, otherLabel, dx: dx, isRight: true) && verticalOK(label, otherLabel, dy: dy) {
                    let newText = smartCombineText(combinedText, otherLabel.text)
                    combinedText = newText
                    combinedX += otherLabel.position.x
                    combinedY += otherLabel.position.y
                    count += 1
                    // Only update primary position if combining with a meaningful label (not "0" noise)
                    if otherLabel.text.trimmingCharacters(in: .whitespaces) != "0" {
                        // For number+unit, keep the number's position
                        if isPrimaryNumber && isUnitOnly(otherLabel.text) {
                            // Keep primary position (number's position)
                            #if DEBUG
                            SVGToTactileParser.debugLog("   [Combine] RIGHT: \"\(combinedText)\" + \"\(otherLabel.text)\" -> keep primary=(\(primaryX),\(primaryY))")
                            #endif
                        } else if isUnitOnly(combinedText) && isNumberOnly(otherLabel.text) {
                            // Unit + number: use number's position
                            primaryX = otherLabel.position.x
                            primaryY = otherLabel.position.y
                            isPrimaryNumber = true
                            #if DEBUG
                            SVGToTactileParser.debugLog("   [Combine] RIGHT: unit + \"\(otherLabel.text)\" -> primary=(\(primaryX),\(primaryY))")
                            #endif
                        }
                    } else {
                        #if DEBUG
                        SVGToTactileParser.debugLog("   [Combine] RIGHT: skipping \"0\" noise, primary stays=(\(primaryX),\(primaryY))")
                        #endif
                    }
                    used.insert(otherLabel.id)
                }
            }

            // Unit+number by distance (e.g. "35" above, "IN" on left – different regions, same measurement)
            // Allow even if count > 1 (e.g. "35" + "0" = "35", still needs "in")
            let unitNumberRadius: CGFloat = 350.0
            let meUnit = isUnitOnly(combinedText)
            let meNum = isNumberOnly(combinedText)
            #if DEBUG
            if meUnit || meNum {
                SVGToTactileParser.debugLog("   [Combine] Checking distance-pair for \"\(combinedText)\" (unit=\(meUnit), num=\(meNum), count=\(Int(count)))")
            }
            #endif
            if meUnit || meNum {
                for otherLabel in sortedLabels {
                    if used.contains(otherLabel.id) || otherLabel.id == label.id { continue }
                    let dx = otherLabel.position.x - combinedX
                    let dy = otherLabel.position.y - combinedY
                    let d = sqrt(dx * dx + dy * dy)
                    guard d < unitNumberRadius else { continue }
                    let otherUnit = isUnitOnly(otherLabel.text)
                    let otherNum = isNumberOnly(otherLabel.text)
                    guard (meUnit && otherNum) || (meNum && otherUnit) else { continue }
                    #if DEBUG
                    SVGToTactileParser.debugLog("   [Combine] Distance-pair: \"\(combinedText)\" + \"\(otherLabel.text)\" dist=\(String(format: "%.0f", d))")
                    #endif
                    let newText = smartCombineText(combinedText, otherLabel.text)
                    combinedText = newText
                    // When combining number + unit via distance, use the NUMBER's ORIGINAL position
                    if meNum && otherUnit {
                        // We have a number, adding a unit - use the ORIGINAL number's position (primaryX/Y)
                        // Don't use combinedX/Y which may have been averaged with "0"
                        isPrimaryNumber = true
                        // primaryX/Y already set to original number position
                        #if DEBUG
                        SVGToTactileParser.debugLog("   [Combine] Distance-pair: number+unit, keeping primary=(\(primaryX),\(primaryY)) [original number pos]")
                        #endif
                    } else if meUnit && otherNum {
                        // We have a unit, adding a number - use number's position
                        primaryX = otherLabel.position.x
                        primaryY = otherLabel.position.y
                        isPrimaryNumber = true
                        #if DEBUG
                        SVGToTactileParser.debugLog("   [Combine] Distance-pair: unit+number, setting primary=(\(primaryX),\(primaryY)) [number's pos]")
                        #endif
                    }
                    combinedX += otherLabel.position.x
                    combinedY += otherLabel.position.y
                    count += 1
                    used.insert(otherLabel.id)
                    break
                }
            }
            
            // Clean up the final text
            let cleanedText = cleanMeasurementText(combinedText)
            
            // Never show standalone unit-only labels (e.g. orphan "IN" on the left)
            if isUnitOnly(cleanedText) {
                #if DEBUG
                SVGToTactileParser.debugLog("   [Combine] SKIP standalone unit: id=\(label.id) text=\"\(cleanedText)\" pos=(\(label.position.x),\(label.position.y))")
                #endif
                used.insert(label.id)
                continue
            }
            
            // Never show standalone "0" labels (OCR noise - periods misread as zeros)
            if cleanedText.trimmingCharacters(in: .whitespaces) == "0" {
                #if DEBUG
                SVGToTactileParser.debugLog("   [Combine] SKIP standalone zero: id=\(label.id) text=\"\(cleanedText)\" pos=(\(label.position.x),\(label.position.y))")
                #endif
                used.insert(label.id)
                continue
            }
            
            // Use primary position (number's position) for number+unit combinations, otherwise average
            // Check if final text is "number unit" pattern (e.g. "35 in", "50 ft", "17 yd")
            // Pattern: starts with digits, optional space, then unit (with optional period)
            let hasNumberUnitPattern = cleanedText.range(of: #"^\d+\.?\s*(in|ft|yd|m|cm|mm|mi)\.?"#, options: [.regularExpression, .caseInsensitive]) != nil
            // Also check if we have a number that was combined with a unit (even if pattern doesn't match perfectly)
            let hasUnit = isUnitOnly(cleanedText) || cleanedText.lowercased().contains("in") || cleanedText.lowercased().contains("ft") || cleanedText.lowercased().contains("yd") || cleanedText.lowercased().contains("m") || cleanedText.lowercased().contains("cm") || cleanedText.lowercased().contains("mm") || cleanedText.lowercased().contains("mi")
            let hasNumber = cleanedText.range(of: #"^\d+"#, options: .regularExpression) != nil
            let isNumberUnitCombo = hasNumber && hasUnit && count > 1
            
            let finalX: CGFloat
            let finalY: CGFloat
            if (count > 1 && isPrimaryNumber) || hasNumberUnitPattern || isNumberUnitCombo {
                // Use the number's original position (primaryX/Y)
                finalX = primaryX
                finalY = primaryY
            } else if count > 1 {
                finalX = combinedX / count
                finalY = combinedY / count
            } else {
                finalX = label.position.x
                finalY = label.position.y
            }
            
            #if DEBUG
            if count > 1 {
                if isPrimaryNumber || hasNumberUnitPattern || isNumberUnitCombo {
                    SVGToTactileParser.debugLog("   [Combine] OUT combined: text=\"\(cleanedText)\" count=\(Int(count)) pos=(\(finalX),\(finalY)) [using number position: primary=(\(primaryX),\(primaryY)), pattern=\(hasNumberUnitPattern), combo=\(isNumberUnitCombo)]")
                } else {
                    SVGToTactileParser.debugLog("   [Combine] OUT combined: text=\"\(cleanedText)\" count=\(Int(count)) pos=(\(finalX),\(finalY)) [averaged: combined=(\(combinedX/count),\(combinedY/count))]")
                }
            } else {
                SVGToTactileParser.debugLog("   [Combine] OUT single: id=\(label.id) text=\"\(cleanedText)\" pos=(\(finalX),\(finalY))")
            }
            #endif
            
            combined.append(TactileLabel(
                id: label.id,
                position: CGPoint(x: finalX, y: finalY),
                text: cleanedText,
                nearestLineId: nil,
                estimatedSize: estimateTextSize(cleanedText)
            ))
            
            used.insert(label.id)
        }
        
        return combined
    }
    
    private static let unitPatterns = ["ft", "in", "yd", "m", "cm", "mm", "mi", "ft.", "in.", "yd."]
    
    private static func isUnitOnly(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces).lowercased()
        let t2 = t.replacingOccurrences(of: ".", with: "")
        return unitPatterns.contains(t) || unitPatterns.contains(t2)
    }

    private static func isNumberOnly(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return false }
        return t.allSatisfy { $0.isNumber || $0 == "." }
    }
    
    private static func smartCombineText(_ first: String, _ second: String) -> String {
        let firstTrimmed = first.trimmingCharacters(in: .whitespaces)
        let secondTrimmed = second.trimmingCharacters(in: .whitespaces)
        
        // Skip combining if second is just "0" - likely a misread period or noise
        // Only combine "0" if first clearly needs a decimal point
        if secondTrimmed == "0" {
            // Check if first ends with a number followed by space (like "35 " or "5.")
            // In this case, "0" is probably noise from OCR, skip it
            if firstTrimmed.last?.isNumber == true || firstTrimmed.hasSuffix(".") {
                // "35" + "0" or "5." + "0" - the 0 is probably a misread period, ignore it
                return firstTrimmed
            }
            // Also skip if first already contains a unit-like pattern (e.g. "50n", "35ft")
            let firstLower = firstTrimmed.lowercased()
            if firstLower.contains("n") || firstLower.contains("ft") || firstLower.contains("yd") ||
               firstLower.contains("in") || firstLower.contains("m") || firstLower.contains("cm") {
                // "50n" + "0" - skip the "0", we'll clean "50n" to "50 in" later
                return firstTrimmed
            }
            // Otherwise skip the "0" entirely
            return firstTrimmed
        }
        
        let firstLower = firstTrimmed.lowercased()
        let secondLower = secondTrimmed.lowercased()
        let isFirstUnit = isUnitOnly(firstTrimmed)
        let isSecondUnit = isUnitOnly(secondTrimmed)
        
        // "in" + "35" or "ft" + "5" -> "35 in" / "5 ft" (unit on left, number on right)
        if isFirstUnit && !isSecondUnit {
            let secondIsNumber = secondTrimmed.allSatisfy { $0.isNumber || $0 == "." }
            if secondIsNumber {
                return secondTrimmed + " " + firstTrimmed
            }
        }
        
        // "35" + "ft" -> "35 ft" (number + unit on right)
        if isSecondUnit {
            let endsWithNumber = firstTrimmed.last?.isNumber ?? false
            if endsWithNumber {
                return firstTrimmed + " " + secondTrimmed
            }
        }
        
        // Check if both are numbers that should be combined
        let firstIsNumber = firstTrimmed.allSatisfy { $0.isNumber || $0 == "." }
        let secondIsNumber = secondTrimmed.allSatisfy { $0.isNumber || $0 == "." }
        
        if firstIsNumber && secondIsNumber && firstTrimmed.count <= 2 && secondTrimmed.count <= 2 {
            // "3" + "5" -> "35" (split number)
            return firstTrimmed + secondTrimmed
        }
        
        // Default: add space
        return firstTrimmed + " " + secondTrimmed
    }
    
    private static func cleanMeasurementText(_ text: String) -> String {
        var cleaned = text
        
        // Fix common OCR issues: "0n" → " in", "50n" → "50 in", etc.
        // Pattern: one or more digits followed by "n", "ft", "yd" (without space)
        let ocrPatterns = [
            (pattern: "(\\d+)n", replacement: "$1 in"),
            (pattern: "(\\d+)ft", replacement: "$1 ft"),
            (pattern: "(\\d+)yd", replacement: "$1 yd")
        ]
        for (pattern, replacement) in ocrPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(location: 0, length: (cleaned as NSString).length),
                    withTemplate: replacement
                )
            }
        }
        
        // Normalize unit case: "IN" -> "in", "FT" -> "ft", etc. (standalone units)
        if let regex = try? NSRegularExpression(pattern: "\\b(IN|FT|YD|M|CM|MM|MI)\\b", options: []) {
            let nsString = cleaned as NSString
            let matches = regex.matches(in: cleaned, options: [], range: NSRange(location: 0, length: nsString.length))
            var result = cleaned
            // Process in reverse to preserve indices
            for match in matches.reversed() {
                let unit = nsString.substring(with: match.range)
                result = (result as NSString).replacingCharacters(in: match.range, with: unit.lowercased())
            }
            cleaned = result
        }
        
        // Normalize spacing around units
        let units = ["ft", "in", "yd", "m", "cm", "mm"]
        for unit in units {
            // Add space before unit if missing: "35ft" -> "35 ft"
            let pattern = "(\\d)(\(unit))"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    options: [],
                    range: NSRange(location: 0, length: (cleaned as NSString).length),
                    withTemplate: "$1 $2"
                )
            }
        }
        
        // Remove trailing periods that aren't part of decimals or units (keep "in.", "ft.")
        if cleaned.hasSuffix(".") {
            let beforePeriod = String(cleaned.dropLast())
            if beforePeriod.last?.isNumber == false {
                let beforeLower = beforePeriod.lowercased()
                let isUnitWithPeriod = ["in", "ft", "yd"].contains(where: { beforeLower.hasSuffix($0) })
                if !isUnitWithPeriod {
                    cleaned = beforePeriod
                }
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Connectivity Analysis
    
    private static func buildVertexGraph(lines: [TactileLineSegment], circles: [TactileVertex]) -> [TactileVertex] {
        var vertices: [TactileVertex] = []
        let tolerance: CGFloat = 8.0
        
        // Start with circles (explicit vertices)
        vertices.append(contentsOf: circles)
        
        // Create vertex map for connectivity
        var vertexMap: [String: [String]] = [:]
        
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
        
        // Update vertices with connected lines and indices
        return vertices.enumerated().map { index, vertex in
            TactileVertex(
                id: vertex.id,
                position: vertex.position,
                connectedLineIds: vertexMap[vertex.id] ?? [],
                vertexIndex: index + 1
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
            id: "vertex_\(existingVertices.count)",
            position: point,
            connectedLineIds: [],
            vertexIndex: existingVertices.count + 1
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
        // and not critical for basic tactile feedback
        return []
    }
    
    // MARK: - Label Association
    
    private static func associateLabelsWithLines(
        labels: [TactileLabel],
        lines: [TactileLineSegment]
    ) -> [TactileLabel] {
        return labels.map { label in
            var nearestLineId: String?
            var nearestLine: TactileLineSegment?
            var minDistance = CGFloat.infinity
            
            for line in lines {
                // Calculate perpendicular distance to line segment
                let distToLine = line.distance(to: label.position)
                
                // Also check if label is positioned along the line segment (not just perpendicular)
                // Project label onto line to see if it's near the segment
                let dx = line.end.x - line.start.x
                let dy = line.end.y - line.start.y
                let lenSq = dx * dx + dy * dy
                
                var isNearLineSegment = false
                var projectionT: CGFloat = 0.5
                if lenSq > 0 {
                    let toLabelX = label.position.x - line.start.x
                    let toLabelY = label.position.y - line.start.y
                    projectionT = (toLabelX * dx + toLabelY * dy) / lenSq
                    
                    // Check if projection is within or near the line segment (with some margin)
                    // Allow labels slightly outside the segment bounds
                    let margin: CGFloat = 0.3 // Allow 30% margin beyond segment ends
                    isNearLineSegment = projectionT >= -margin && projectionT <= (1.0 + margin)
                } else {
                    // Degenerate line (zero length) - check if label is very close to the point
                    isNearLineSegment = distToLine < 20
                }
                
                // Only consider lines where label is reasonably close
                // Use stricter threshold: 60 for horizontal/vertical, 80 for diagonal
                let threshold: CGFloat = (line.isHorizontal || line.isVertical) ? 60 : 80
                
                // Use perpendicular distance as primary metric
                // Only apply small penalties for clearly wrong associations
                var associationScore = distToLine
                
                // Small penalty if association doesn't make geometric sense (but don't exclude)
                if line.isVertical {
                    let horizontalDist = abs(label.position.x - line.start.x)
                    if horizontalDist > 150 { // Very far horizontally
                        associationScore += 30 // Small penalty, but still allow if closest
                    }
                } else if line.isHorizontal {
                    let verticalDist = abs(label.position.y - line.start.y)
                    if verticalDist > 150 { // Very far vertically
                        associationScore += 30 // Small penalty, but still allow if closest
                    }
                }
                
                // Label must be close perpendicularly AND near the line segment
                // Use raw distance for comparison, score only for tie-breaking
                if distToLine < threshold && isNearLineSegment {
                    if distToLine < minDistance {
                        minDistance = distToLine
                        nearestLineId = line.id
                        nearestLine = line
                    } else if abs(distToLine - minDistance) < 5 {
                        // Very close distances - use score to break tie
                        if associationScore < minDistance {
                            minDistance = associationScore
                            nearestLineId = line.id
                            nearestLine = line
                        }
                    }
                }
            }
            
            // Adjust position based on line orientation
            // CONSERVATIVE: Only adjust if label is clearly in wrong position (too close/overlapping)
            var adjustedPosition = label.position
            if let line = nearestLine {
                let offset: CGFloat = 25.0 // Offset distance from line
                let minOffset: CGFloat = 15.0 // Minimum acceptable offset
                
                if line.isHorizontal {
                    // For horizontal lines, position label ABOVE the line
                    let lineY = line.start.y
                    let currentOffset = lineY - label.position.y
                    
                    // Only adjust if:
                    // 1. Label is below the line (negative offset)
                    // 2. Label is too close to the line (less than minOffset)
                    if currentOffset < minOffset {
                        // Label needs adjustment - move it above
                        adjustedPosition = CGPoint(x: label.position.x, y: lineY - offset)
                    } else {
                        // Label is already in good position - preserve original
                        adjustedPosition = label.position
                    }
                } else if line.isVertical {
                    // For vertical lines, respect which side the label is on originally
                    let lineX = line.start.x
                    let distanceFromLine = abs(label.position.x - lineX)
                    let isOnRightSide = label.position.x > lineX
                    
                    // Very conservative: only adjust if label is VERY close (overlapping or almost overlapping)
                    // If label is already at reasonable distance (> 20pt), preserve it completely
                    if distanceFromLine < 20 {
                        // Label is very close - move it to appropriate side
                        if isOnRightSide {
                            // Keep it on the right side
                            adjustedPosition = CGPoint(x: lineX + offset, y: label.position.y)
                        } else {
                            // Keep it on the left side
                            adjustedPosition = CGPoint(x: lineX - offset, y: label.position.y)
                        }
                    } else {
                        // Label is already at good distance (> 20pt) - preserve original position completely
                        adjustedPosition = label.position
                    }
                } else {
                    // For diagonal lines, project label position onto line, then offset perpendicularly
                    let dx = line.end.x - line.start.x
                    let dy = line.end.y - line.start.y
                    let length = sqrt(dx * dx + dy * dy)
                    guard length > 0 else { return TactileLabel(id: label.id, position: label.position, text: label.text, nearestLineId: nearestLineId, estimatedSize: label.estimatedSize) }
                    
                    // Vector from line start to label position
                    let toLabelX = label.position.x - line.start.x
                    let toLabelY = label.position.y - line.start.y
                    
                    // Project onto line direction
                    let t = (toLabelX * dx + toLabelY * dy) / (length * length)
                    let clampedT = max(0, min(1, t)) // Clamp to line segment
                    
                    // Closest point on line
                    let closestX = line.start.x + clampedT * dx
                    let closestY = line.start.y + clampedT * dy
                    
                    // Perpendicular vector (rotate 90 degrees counterclockwise)
                    let perpX = -dy / length
                    let perpY = dx / length
                    
                    // Determine which side the label is on
                    let sideX = label.position.x - closestX
                    let sideY = label.position.y - closestY
                    let dot = sideX * perpX + sideY * perpY
                    
                    // Prefer positioning above/left (negative perpendicular direction for typical orientation)
                    // But respect which side the label is actually on
                    let perpDir: CGFloat = dot >= 0 ? 1 : -1
                    adjustedPosition = CGPoint(
                        x: closestX + perpDir * perpX * offset,
                        y: closestY + perpDir * perpY * offset
                    )
                }
                
                #if DEBUG
                if line.isVertical {
                    SVGToTactileParser.debugLog("   [Position] Label \"\(label.text)\": original=(\(label.position.x),\(label.position.y)) -> adjusted=(\(adjustedPosition.x),\(adjustedPosition.y)) [line: vertical, lineX=\(line.start.x), offset=\(offset)]")
                } else {
                    SVGToTactileParser.debugLog("   [Position] Label \"\(label.text)\": original=(\(label.position.x),\(label.position.y)) -> adjusted=(\(adjustedPosition.x),\(adjustedPosition.y)) [line: \(line.isHorizontal ? "horizontal" : "diagonal")]")
                }
                #endif
            }
            
            return TactileLabel(
                id: label.id,
                position: adjustedPosition,
                text: label.text,
                nearestLineId: nearestLineId,
                estimatedSize: label.estimatedSize
            )
        }
    }
    
    // MARK: - Transform Creation
    
    private static func createTransform(from source: CGRect, to destination: CGSize) -> CGAffineTransform {
        guard source.width > 0 && source.height > 0 else {
            return .identity
        }
        
        let scaleX = destination.width / source.width
        let scaleY = destination.height / source.height
        
        // Use uniform scaling to maintain aspect ratio
        let scale = min(scaleX, scaleY)
        
        // Center the content
        let offsetX = (destination.width - source.width * scale) / 2 - source.origin.x * scale
        let offsetY = (destination.height - source.height * scale) / 2 - source.origin.y * scale
        
        return CGAffineTransform(translationX: offsetX, y: offsetY).scaledBy(x: scale, y: scale)
    }
    
    // MARK: - Metadata Extraction
    
    private static func extractTitle(from svg: String) -> String? {
        if let metadata = extractMetadataJSON(from: svg),
           let title = metadata["title"] as? String {
            return title
        }
        return nil
    }
    
    private static func extractDescriptions(from svg: String) -> [String]? {
        if let metadata = extractMetadataJSON(from: svg) {
            if let longDesc = metadata["long_desc"] as? [String] {
                return longDesc
            }
            if let summary = metadata["summary"] as? [String] {
                return summary
            }
            if let summary = metadata["summary"] as? String {
                return [summary]
            }
        }
        return nil
    }
    
    private static func extractMetadataJSON(from svg: String) -> [String: Any]? {
        let pattern = #"<metadata>([\s\S]*?)</metadata>"#
        let nsString = svg as NSString
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: svg, options: [], range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges >= 2 else {
            return nil
        }
        
        let metadataContent = nsString.substring(with: match.range(at: 1))
        
        // Find JSON object within metadata
        let jsonPattern = #"\{[\s\S]*\}"#
        guard let jsonRegex = try? NSRegularExpression(pattern: jsonPattern, options: []),
              let jsonMatch = jsonRegex.firstMatch(in: metadataContent, options: [], range: NSRange(location: 0, length: (metadataContent as NSString).length)) else {
            return nil
        }
        
        let jsonString = (metadataContent as NSString).substring(with: jsonMatch.range)
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        
        return try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
    }
}