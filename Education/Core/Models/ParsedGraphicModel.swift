//
//  ParsedGraphicModel.swift
//  Education
//
//  Clean JSON-serializable model for parsed SVG graphics
//  Separates parsing from rendering for better maintainability

import Foundation
import SwiftUI

// MARK: - Parsed Graphic (JSON-serializable)

struct ParsedGraphic: Codable {
    let viewBox: ViewBox
    let lines: [ParsedLine]
    let labels: [ParsedLabel]
    let vertices: [ParsedVertex]
    let title: String?
    let description: String?
}

struct ViewBox: Codable {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    
    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

struct ParsedLine: Codable, Identifiable {
    let id: String
    let start: Point
    let end: Point
    let strokeWidth: CGFloat
    let orientation: LineOrientation
    
    enum LineOrientation: String, Codable {
        case horizontal
        case vertical
        case diagonal
    }
    
    var cgStart: CGPoint { CGPoint(x: start.x, y: start.y) }
    var cgEnd: CGPoint { CGPoint(x: end.x, y: end.y) }
}

struct ParsedLabel: Codable, Identifiable {
    let id: String
    let text: String
    let position: Point
    let nearestLineId: String?
    let anchor: LabelAnchor
    
    enum LabelAnchor: String, Codable {
        case above      // For horizontal lines
        case left       // For vertical lines
        case right      // For vertical lines (alternative)
        case diagonal   // For diagonal lines
    }
}

struct ParsedVertex: Codable, Identifiable {
    let id: String
    let position: Point
}

struct Point: Codable {
    let x: CGFloat
    let y: CGFloat
    
    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

// MARK: - Converter: TactileScene -> ParsedGraphic

extension ParsedGraphic {
    static func from(_ scene: TactileScene) -> ParsedGraphic {
        let lines = scene.lineSegments.map { line in
            let orientation: ParsedLine.LineOrientation
            if line.isHorizontal {
                orientation = .horizontal
            } else if line.isVertical {
                orientation = .vertical
            } else {
                orientation = .diagonal
            }
            
            return ParsedLine(
                id: line.id,
                start: Point(x: line.start.x, y: line.start.y),
                end: Point(x: line.end.x, y: line.end.y),
                strokeWidth: line.strokeWidth,
                orientation: orientation
            )
        }
        
        let labels = scene.labels.map { label in
            // Determine anchor based on nearest line
            let anchor: ParsedLabel.LabelAnchor
            if let lineId = label.nearestLineId,
               let line = scene.lineSegments.first(where: { $0.id == lineId }) {
                if line.isHorizontal {
                    anchor = .above
                } else if line.isVertical {
                    anchor = .left
                } else {
                    anchor = .diagonal
                }
            } else {
                anchor = .diagonal // Default
            }
            
            return ParsedLabel(
                id: label.id,
                text: label.text,
                position: Point(x: label.position.x, y: label.position.y),
                nearestLineId: label.nearestLineId,
                anchor: anchor
            )
        }
        
        let vertices = scene.vertices.map { vertex in
            ParsedVertex(
                id: vertex.id,
                position: Point(x: vertex.position.x, y: vertex.position.y)
            )
        }
        
        return ParsedGraphic(
            viewBox: ViewBox(
                x: scene.viewBox.origin.x,
                y: scene.viewBox.origin.y,
                width: scene.viewBox.width,
                height: scene.viewBox.height
            ),
            lines: lines,
            labels: labels,
            vertices: vertices,
            title: scene.title,
            description: scene.descriptions?.first
        )
    }
}

// MARK: - Converter: ParsedGraphic -> TactileScene (for rendering)

extension TactileScene {
    static func from(_ parsed: ParsedGraphic) -> TactileScene {
        let lines = parsed.lines.map { line in
            TactileLineSegment(
                id: line.id,
                start: line.cgStart,
                end: line.cgEnd,
                strokeWidth: line.strokeWidth,
                associatedLabel: nil
            )
        }
        
        let labels = parsed.labels.map { label in
            TactileLabel(
                id: label.id,
                position: label.position.cgPoint,
                text: label.text,
                nearestLineId: label.nearestLineId,
                estimatedSize: nil
            )
        }
        
        let vertices = parsed.vertices.map { vertex in
            TactileVertex(
                id: vertex.id,
                position: vertex.position.cgPoint,
                connectedLineIds: [],
                vertexIndex: nil
            )
        }
        
        return TactileScene(
            id: UUID().uuidString,
            lineSegments: lines,
            polygons: [],
            vertices: vertices,
            labels: labels,
            viewBox: parsed.viewBox.cgRect,
            transform: .identity,
            title: parsed.title,
            descriptions: parsed.description.map { [$0] }
        )
    }
}
