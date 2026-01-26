//
//  SimpleGraphicView.swift
//  Education
//
//  Simplified graphic renderer using ParsedGraphic model
//  Clean separation of parsing and rendering

import SwiftUI

struct SimpleGraphicView: View {
    let parsedGraphic: ParsedGraphic
    
    var body: some View {
        GeometryReader { geometry in
            let scale = min(
                geometry.size.width / parsedGraphic.viewBox.width,
                geometry.size.height / parsedGraphic.viewBox.height
            )
            let offsetX = (geometry.size.width - parsedGraphic.viewBox.width * scale) / 2
            let offsetY = (geometry.size.height - parsedGraphic.viewBox.height * scale) / 2
            
            ZStack {
                // Draw lines
                ForEach(parsedGraphic.lines) { line in
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
                    .stroke(Color.black, lineWidth: line.strokeWidth * scale)
                }
                
                // Draw vertices
                ForEach(parsedGraphic.vertices) { vertex in
                    Circle()
                        .fill(Color.black)
                        .frame(width: 8 * scale, height: 8 * scale)
                        .position(
                            x: vertex.position.x * scale + offsetX,
                            y: vertex.position.y * scale + offsetY
                        )
                }
                
                // Draw labels with proper positioning
                ForEach(parsedGraphic.labels) { label in
                    let baseX = label.position.x * scale + offsetX
                    let baseY = label.position.y * scale + offsetY
                    
                    // Adjust position based on anchor
                    let (finalX, finalY) = adjustLabelPosition(
                        baseX: baseX,
                        baseY: baseY,
                        anchor: label.anchor,
                        line: label.nearestLineId.flatMap { lineId in
                            parsedGraphic.lines.first { $0.id == lineId }
                        },
                        scale: scale
                    )
                    
                    Text(label.text)
                        .font(.system(size: 12 * scale))
                        .foregroundColor(.black)
                        .position(x: finalX, y: finalY)
                }
            }
        }
        .aspectRatio(
            parsedGraphic.viewBox.width / parsedGraphic.viewBox.height,
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

// MARK: - Convenience initializer from SVG string

extension SimpleGraphicView {
    init(svgContent: String) {
        // Parse SVG into ParsedGraphic
        if let parsed = GraphicParserService.parse(svgContent: svgContent) {
            self.parsedGraphic = parsed
        } else {
            // Fallback: create empty graphic
            self.parsedGraphic = ParsedGraphic(
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
