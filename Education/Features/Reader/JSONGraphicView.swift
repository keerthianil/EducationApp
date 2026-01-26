//
//  JSONGraphicView.swift
//  Education
//
//  Render graphics from JSON (like map app approach)
//  Clean, simple rendering from structured data

import SwiftUI

struct JSONGraphicView: View {
    let graphic: ParsedGraphic
    
    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / graphic.viewBox.width,
                geometry.size.height / graphic.viewBox.height
            )
            let offsetX = (geometry.size.width - graphic.viewBox.width * scale) / 2
            let offsetY = (geometry.size.height - graphic.viewBox.height * scale) / 2
            
            ZStack {
                // Draw lines
                ForEach(graphic.lines) { line in
                    Path { path in
                        path.move(to: CGPoint(
                            x: line.start.x * scale + offsetX,
                            y: line.start.y * scale + offsetY
                        ))
                        path.addLine(to: CGPoint(
                            x: line.end.x * scale + offsetX,
                            y: line.end.y * scale + offsetY
                        ))
                    }
                    .stroke(Color.black, lineWidth: max(2.0, line.strokeWidth * scale))
                }
                
                // Draw vertices
                ForEach(graphic.vertices) { vertex in
                    Circle()
                        .fill(Color.black)
                        .frame(width: 8 * scale, height: 8 * scale)
                        .position(
                            x: vertex.position.x * scale + offsetX,
                            y: vertex.position.y * scale + offsetY
                        )
                }
                
                // Draw labels with proper positioning
                ForEach(graphic.labels) { label in
                    let baseX = label.position.x * scale + offsetX
                    let baseY = label.position.y * scale + offsetY
                    
                    // Adjust position based on anchor (from JSON)
                    let (finalX, finalY) = adjustLabelPosition(
                        baseX: baseX,
                        baseY: baseY,
                        anchor: label.anchor,
                        line: label.nearestLineId.flatMap { lineId in
                            graphic.lines.first { $0.id == lineId }
                        },
                        scale: scale
                    )
                    
                    Text(label.text)
                        .font(.system(size: max(12, 14 * scale), weight: .semibold))
                        .foregroundColor(.black)
                        .position(x: finalX, y: finalY)
                }
            }
        }
        .aspectRatio(
            graphic.viewBox.width / graphic.viewBox.height,
            contentMode: .fit
        )
    }
    
    private func adjustLabelPosition(
        baseX: CGFloat,
        baseY: CGFloat,
        anchor: ParsedLabel.LabelAnchor,
        line: ParsedLine?,
        scale: CGFloat
    ) -> (x: CGFloat, y: CGFloat) {
        let offset: CGFloat = 20 * scale
        
        switch anchor {
        case .above:
            // For horizontal lines, position above
            if let line = line {
                let lineY = (line.start.y + line.end.y) / 2 * scale
                return (baseX, lineY - offset)
            }
            return (baseX, baseY - offset)
            
        case .left:
            // For vertical lines, position to the left
            if let line = line {
                let lineX = (line.start.x + line.end.x) / 2 * scale
                return (lineX - offset, baseY)
            }
            return (baseX - offset, baseY)
            
        case .right:
            // For vertical lines, position to the right
            if let line = line {
                let lineX = (line.start.x + line.end.x) / 2 * scale
                return (lineX + offset, baseY)
            }
            return (baseX + offset, baseY)
            
        case .diagonal:
            // Keep original position with small offset
            return (baseX, baseY - offset / 2)
        }
    }
}

// MARK: - Convenience initializer from JSON data

extension JSONGraphicView {
    init(jsonData: Data) {
        // Load from JSON (like map app)
        if let graphic = SVGToJSONConverter.loadFromJSON(data: jsonData) {
            self.graphic = graphic
        } else {
            // Fallback: empty graphic
            self.graphic = ParsedGraphic(
                viewBox: ViewBox(x: 0, y: 0, width: 100, height: 100),
                lines: [],
                labels: [],
                vertices: [],
                title: nil,
                description: nil
            )
        }
    }
}
