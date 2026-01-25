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
}

// MARK: - Vertex (intersection point)

struct TactileVertex: Identifiable {
    let id: String
    let position: CGPoint
    let connectedLineIds: [String]    // IDs of lines meeting here
    
    func contains(point: CGPoint, tolerance: CGFloat = 10.0) -> Bool {
        let dx = point.x - position.x
        let dy = point.y - position.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance <= tolerance
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
    
    func contains(point: CGPoint, tolerance: CGFloat = 20.0) -> Bool {
        let dx = point.x - position.x
        let dy = point.y - position.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance <= tolerance
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
