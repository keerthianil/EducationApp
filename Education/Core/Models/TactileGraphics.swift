//
//  TactileGraphics.swift
//  Education
//
//  Tactile graphics model for blind users - represents SVG as touchable primitives

import Foundation
import SwiftUI

// MARK: - Tactile Scene (complete graphic representation)

struct TactileScene: Identifiable {
    let id: String
    let lineSegments: [TactileLineSegment]
    let polygons: [TactilePolygon]
    let vertices: [TactileVertex]
    let labels: [TactileLabel]
    let viewBox: CGRect
    let transform: CGAffineTransform
    let title: String?
    let descriptions: [String]?
    
    var allPrimitives: [TactilePrimitive] {
        var primitives: [TactilePrimitive] = []
        primitives.append(contentsOf: lineSegments.map { .lineSegment($0) })
        primitives.append(contentsOf: polygons.map { .polygon($0) })
        primitives.append(contentsOf: vertices.map { .vertex($0) })
        primitives.append(contentsOf: labels.map { .label($0) })
        return primitives
    }
    
    /// Returns a summary description for VoiceOver
    var accessibilitySummary: String {
        var parts: [String] = []
        
        if let title = title {
            parts.append(title)
        }
        
        let vertexCount = vertices.count
        let edgeCount = lineSegments.count
        let labelCount = labels.filter { !$0.text.isEmpty }.count
        
        if vertexCount > 0 {
            parts.append("\(vertexCount) corner\(vertexCount == 1 ? "" : "s")")
        }
        if edgeCount > 0 {
            parts.append("\(edgeCount) edge\(edgeCount == 1 ? "" : "s")")
        }
        if labelCount > 0 {
            parts.append("\(labelCount) measurement\(labelCount == 1 ? "" : "s")")
        }
        
        return parts.joined(separator: ", ")
    }
}

// MARK: - Tactile Primitive Types

enum TactilePrimitive: Identifiable {
    case lineSegment(TactileLineSegment)
    case polygon(TactilePolygon)
    case vertex(TactileVertex)
    case label(TactileLabel)
    
    var id: String {
        switch self {
        case .lineSegment(let line): return line.id
        case .polygon(let polygon): return polygon.id
        case .vertex(let vertex): return vertex.id
        case .label(let label): return label.id
        }
    }
    
    var accessibilityDescription: String {
        switch self {
        case .lineSegment(let line): return line.accessibilityDescription
        case .polygon(let polygon): return polygon.accessibilityDescription
        case .vertex(let vertex): return vertex.accessibilityDescription
        case .label(let label): return label.accessibilityDescription
        }
    }
}

// MARK: - Line Segment (from SVG <line>)

struct TactileLineSegment: Identifiable {
    let id: String
    let start: CGPoint
    let end: CGPoint
    let strokeWidth: CGFloat
    let associatedLabel: String?        // Measurement text nearby
    
    var length: CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Angle in degrees (-180 to 180)
    var angle: CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return atan2(dy, dx) * 180 / .pi
    }
    
    var isHorizontal: Bool {
        let normalizedAngle = abs(angle.truncatingRemainder(dividingBy: 180))
        return normalizedAngle < 15 || normalizedAngle > 165
    }
    
    var isVertical: Bool {
        let normalizedAngle = abs(angle.truncatingRemainder(dividingBy: 180))
        return normalizedAngle > 75 && normalizedAngle < 105
    }
    
    /// Returns the midpoint of the line
    var midpoint: CGPoint {
        CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
    }
    
    var accessibilityDescription: String {
        var description: String
        
        if isHorizontal {
            description = "Horizontal edge"
        } else if isVertical {
            description = "Vertical edge"
        } else {
            description = "Diagonal edge"
        }
        
        if let label = associatedLabel, !label.isEmpty {
            description += ", \(label)"
        }
        
        return description
    }
    
    func contains(point: CGPoint, tolerance: CGFloat = 15.0) -> Bool {
        distance(to: point) <= tolerance
    }
    
    func distance(to point: CGPoint) -> CGFloat {
        // Point-to-line-segment distance
        let A = point.x - start.x
        let B = point.y - start.y
        let C = end.x - start.x
        let D = end.y - start.y
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        let param = lenSq != 0 ? dot / lenSq : -1
        
        var xx: CGFloat
        var yy: CGFloat
        
        if param < 0 {
            xx = start.x
            yy = start.y
        } else if param > 1 {
            xx = end.x
            yy = end.y
        } else {
            xx = start.x + param * C
            yy = start.y + param * D
        }
        
        let dx = point.x - xx
        let dy = point.y - yy
        return sqrt(dx * dx + dy * dy)
    }
    
    func progressAlongLine(point: CGPoint) -> CGFloat {
        // Returns 0.0 to 1.0 indicating position along line
        let A = point.x - start.x
        let B = point.y - start.y
        let C = end.x - start.x
        let D = end.y - start.y
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        let param = lenSq != 0 ? dot / lenSq : -1
        
        return max(0, min(1, param))
    }
}

// MARK: - Polygon (closed shape from connected lines)

struct TactilePolygon: Identifiable {
    let id: String
    let boundary: [CGPoint]           // Closed path vertices
    let interior: Bool                // Filled or just outline
    let label: String?                // Shape description
    let componentLineIds: [String]    // IDs of lines forming this polygon
    
    func contains(_ point: CGPoint) -> Bool {
        guard !boundary.isEmpty else { return false }
        return pointInPolygon(point: point, polygon: boundary)
    }
    
    var sideCount: Int {
        boundary.count
    }
    
    var shapeType: String {
        switch sideCount {
        case 3: return "triangle"
        case 4: return "quadrilateral"
        case 5: return "pentagon"
        case 6: return "hexagon"
        case 7: return "heptagon"
        case 8: return "octagon"
        default: return "\(sideCount)-sided polygon"
        }
    }
    
    var accessibilityDescription: String {
        if let label = label, !label.isEmpty {
            return "\(shapeType.capitalized), \(label)"
        }
        return shapeType.capitalized
    }
}

// MARK: - Vertex (intersection point)

struct TactileVertex: Identifiable {
    let id: String
    let position: CGPoint
    let connectedLineIds: [String]    // IDs of lines meeting here
    let vertexIndex: Int?             // Optional index for labeling (e.g., "Vertex 1")
    
    init(id: String, position: CGPoint, connectedLineIds: [String], vertexIndex: Int? = nil) {
        self.id = id
        self.position = position
        self.connectedLineIds = connectedLineIds
        self.vertexIndex = vertexIndex
    }
    
    var accessibilityDescription: String {
        let connections = connectedLineIds.count
        var description: String
        
        if let index = vertexIndex {
            description = "Corner \(index)"
        } else {
            description = "Corner point"
        }
        
        if connections > 0 {
            description += ", \(connections) edge\(connections == 1 ? "" : "s") meet here"
        }
        
        return description
    }
    
    func contains(point: CGPoint, tolerance: CGFloat = 20.0) -> Bool {
        distance(to: point) <= tolerance
    }
    
    func distance(to point: CGPoint) -> CGFloat {
        let dx = point.x - position.x
        let dy = point.y - position.y
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Label (text annotation)

struct TactileLabel: Identifiable {
    let id: String
    let position: CGPoint
    let text: String                  // "35 in.", "50 ft."
    let nearestLineId: String?        // Associated line segment ID
    let estimatedSize: CGSize?        // For better hit testing
    
    init(id: String, position: CGPoint, text: String, nearestLineId: String?, estimatedSize: CGSize? = nil) {
        self.id = id
        self.position = position
        self.text = text
        self.nearestLineId = nearestLineId
        self.estimatedSize = estimatedSize
    }
    
    var accessibilityDescription: String {
        if text.isEmpty {
            return "Label"
        }
        return "Measurement: \(text)"
    }
    
    func contains(point: CGPoint, tolerance: CGFloat = 25.0) -> Bool {
        if let size = estimatedSize {
            // Rectangular hit area for text
            let rect = CGRect(
                x: position.x - tolerance,
                y: position.y - size.height - tolerance,
                width: size.width + tolerance * 2,
                height: size.height + tolerance * 2
            )
            return rect.contains(point)
        }
        // Fallback to circular hit area
        return distance(to: point) <= tolerance
    }
    
    func distance(to point: CGPoint) -> CGFloat {
        let dx = point.x - position.x
        let dy = point.y - position.y
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - Hit Test Result

struct HitResult {
    let primitive: TactilePrimitive
    let type: HitType
    let distance: CGFloat
    let point: CGPoint
    
    var accessibilityAnnouncement: String {
        primitive.accessibilityDescription
    }
}

enum HitType {
    case onLine
    case insideShape
    case onVertex
    case onLabel
}

// MARK: - Utility Functions

private func pointInPolygon(point: CGPoint, polygon: [CGPoint]) -> Bool {
    guard polygon.count >= 3 else { return false }
    
    var inside = false
    var j = polygon.count - 1
    
    for i in 0..<polygon.count {
        let xi = polygon[i].x, yi = polygon[i].y
        let xj = polygon[j].x, yj = polygon[j].y
        
        let intersect = ((yi > point.y) != (yj > point.y)) &&
                        (point.x < (xj - xi) * (point.y - yi) / (yj - yi) + xi)
        if intersect {
            inside = !inside
        }
        j = i
    }
    
    return inside
}