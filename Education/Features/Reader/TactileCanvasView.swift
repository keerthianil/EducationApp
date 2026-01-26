//
//  TactileCanvasView.swift
//  Education
//
//  Tactile canvas view for blind users - renders graphics with touch exploration

import SwiftUI
import UIKit

struct TactileCanvasView: View {
    let scene: TactileScene
    let title: String?
    let summaries: [String]?
    
    @State private var currentTouch: CGPoint?
    @State private var activeHit: HitResult?
    @State private var exploredPath: [CGPoint] = []
    @State private var canvasSize: CGSize = .zero
    @State private var haptics = TactileHapticEngine()
    @State private var showMultisensoryView = false
    @State private var isProcessingDoubleTap = false
    @State private var lastAnnouncedProgress: CGFloat = -1
    
    private var accessibilityDescription: String {
        var desc = title ?? "Graphic"
        if let s = summaries, !s.isEmpty {
            desc += ". " + s.joined(separator: ". ")
        }
        return desc
    }

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                GeometryReader { geometry in
                    let canvasWidth = geometry.size.width
                    let canvasHeight = geometry.size.height
                    
                    ZStack(alignment: .center) {
                        // Visual rendering for sighted users
                        Canvas { context, size in
                            let renderSize = CGSize(width: canvasWidth, height: canvasHeight)
                            guard renderSize.width > 0, renderSize.height > 0 else { return }
                            
                            let viewBoxWidth = max(scene.viewBox.width, 1.0)
                            let viewBoxHeight = max(scene.viewBox.height, 1.0)
                            let scaleX = renderSize.width / viewBoxWidth
                            let scaleY = renderSize.height / viewBoxHeight
                            let scale = min(scaleX, scaleY)
                            
                            // Draw all line segments
                            for line in scene.lineSegments {
                                var path = Path()
                                let start = transformPoint(line.start, size: renderSize)
                                let end = transformPoint(line.end, size: renderSize)
                                path.move(to: start)
                                path.addLine(to: end)
                                
                                let scaledStrokeWidth = max(2.0, line.strokeWidth * scale)
                                
                                context.stroke(
                                    path,
                                    with: .color(.black),
                                    lineWidth: scaledStrokeWidth
                                )
                            }
                            
                            // Fill polygons if they have interior
                            for polygon in scene.polygons {
                                if polygon.interior && !polygon.boundary.isEmpty {
                                    var path = Path()
                                    let firstPoint = transformPoint(polygon.boundary[0], size: renderSize)
                                    path.move(to: firstPoint)
                                    for point in polygon.boundary.dropFirst() {
                                        path.addLine(to: transformPoint(point, size: renderSize))
                                    }
                                    path.closeSubpath()
                                    
                                    context.fill(path, with: .color(.gray.opacity(0.1)))
                                    context.stroke(path, with: .color(.gray.opacity(0.3)), lineWidth: 1)
                                }
                            }
                            
                            // Draw vertices as circles - size based on scale
                            let vertexRadius = max(4.0, 6.0 * scale)
                            for vertex in scene.vertices {
                                var path = Path()
                                let center = transformPoint(vertex.position, size: renderSize)
                                path.addEllipse(in: CGRect(
                                    x: center.x - vertexRadius,
                                    y: center.y - vertexRadius,
                                    width: vertexRadius * 2,
                                    height: vertexRadius * 2
                                ))
                                context.fill(path, with: .color(.black))
                            }
                            
                            // Draw labels - larger font for visibility
                            let fontSize = max(14.0, 16.0 * scale)
                            for label in scene.labels {
                                let transformedPos = transformPoint(label.position, size: renderSize)
                                if transformedPos.x >= 0 && transformedPos.x <= renderSize.width &&
                                   transformedPos.y >= 0 && transformedPos.y <= renderSize.height {
                                    context.draw(
                                        Text(label.text)
                                            .font(.system(size: fontSize, weight: .semibold))
                                            .foregroundColor(.black),
                                        at: transformedPos,
                                        anchor: .center
                                    )
                                }
                            }
                        }
                        .frame(width: canvasWidth, height: canvasHeight)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        
                        // Invisible touch overlay
                        if !showMultisensoryView && !isProcessingDoubleTap {
                            TactileTouchOverlay(
                                viewBox: scene.viewBox,
                                canvasSize: $canvasSize,
                                onTouch: handleTouch,
                                onDrag: handleDrag,
                                onEnd: handleTouchEnd
                            )
                            .allowsHitTesting(true)
                        }
                        
                        // Double-tap gesture overlay
                        Color.clear
                            .contentShape(Rectangle())
                            .allowsHitTesting(!showMultisensoryView && !isProcessingDoubleTap)
                            .highPriorityGesture(
                                TapGesture(count: 2)
                                    .onEnded { _ in
                                        guard !showMultisensoryView && !isProcessingDoubleTap else { return }
                                        
                                        isProcessingDoubleTap = true
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            showMultisensoryView = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                isProcessingDoubleTap = false
                                            }
                                        }
                                    }
                            )
                    }
                    .onAppear {
                        canvasSize = CGSize(width: canvasWidth, height: canvasHeight)
                    }
                    .onChange(of: geometry.size) { newSize in
                        canvasSize = newSize
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Button to open multisensory view (hidden from VO; use accessibility action instead)
                Button {
                    guard !showMultisensoryView else { return }
                    UISelectionFeedbackGenerator().selectionChanged()
                    isProcessingDoubleTap = true
                    showMultisensoryView = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isProcessingDoubleTap = false
                    }
                } label: {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color(hex: "#121417").opacity(0.8))
                        .clipShape(Circle())
                }
                .padding(12)
                .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to open multisensory exploration view. Activate to open multisensory view.")
        .accessibilityAddTraits(.isImage)
        .accessibilityAction(named: "Open multisensory view") {
            guard !showMultisensoryView else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            isProcessingDoubleTap = true
            showMultisensoryView = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isProcessingDoubleTap = false
            }
        }
        .onAppear {
            #if DEBUG
            print("[SVG-Parser] TactileCanvasView onAppear: \(scene.labels.count) labels, viewBox=\(scene.viewBox)")
            for (i, lbl) in scene.labels.enumerated() {
                print("[SVG-Parser]   Draw[\(i)] \"\(lbl.text)\" at (\(lbl.position.x),\(lbl.position.y))")
            }
            #endif
            announceInitialDescription()
            haptics.prepare()
        }
        .background(
            NavigationLink(
                destination: MultisensoryTactileView(scene: scene, title: title, summaries: summaries),
                isActive: $showMultisensoryView
            ) {
                EmptyView()
            }
            .hidden()
        )
    }
    
    // MARK: - Coordinate Transformation
    
    /// Transform a point from viewBox coordinates to canvas coordinates
    private func transformPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0,
              scene.viewBox.width > 0, scene.viewBox.height > 0 else {
            return point
        }
        
        // Calculate uniform scale to fit viewBox in canvas while preserving aspect ratio
        let scaleX = size.width / scene.viewBox.width
        let scaleY = size.height / scene.viewBox.height
        let scale = min(scaleX, scaleY)
        
        // Calculate centering offsets
        let scaledWidth = scene.viewBox.width * scale
        let scaledHeight = scene.viewBox.height * scale
        let offsetX = (size.width - scaledWidth) / 2
        let offsetY = (size.height - scaledHeight) / 2
        
        // Transform: (point - viewBox.origin) * scale + offset
        return CGPoint(
            x: (point.x - scene.viewBox.origin.x) * scale + offsetX,
            y: (point.y - scene.viewBox.origin.y) * scale + offsetY
        )
    }
    
    // MARK: - Touch Handling
    
    private func handleTouch(at point: CGPoint) {
        let svgPoint = inverseTransformPoint(point)
        currentTouch = svgPoint
        exploredPath = [svgPoint]
        
        if let hit = scene.hitTest(at: svgPoint) {
            activeHit = hit
            haptics.play(for: hit.type)
            announce(hit: hit)
            
            if hit.type == .onLine {
                haptics.continuous()
            }
        } else {
            activeHit = nil
            haptics.stop()
        }
    }
    
    private func handleDrag(from: CGPoint, to: CGPoint) {
        let svgTo = inverseTransformPoint(to)
        
        exploredPath.append(svgTo)
        currentTouch = svgTo
        
        if let hit = scene.hitTest(at: svgTo) {
            let previousId = activeHit?.primitive.id
            let currentId = hit.primitive.id
            
            if previousId != currentId {
                haptics.pulse()
                activeHit = hit
                haptics.play(for: hit.type)
                announce(hit: hit)
                lastAnnouncedProgress = -1
                
                if hit.type == .onLine {
                    haptics.continuous()
                }
            } else {
                if hit.type == .onLine {
                    haptics.continuous()
                    
                    if case .lineSegment(let line) = hit.primitive {
                        let progress = line.progressAlongLine(point: svgTo)
                        announceProgress(progress: progress, line: line)
                    }
                } else if hit.type == .onVertex {
                    haptics.pulse()
                }
            }
        } else {
            haptics.stop()
            activeHit = nil
            lastAnnouncedProgress = -1
        }
    }
    
    private func announceProgress(progress: CGFloat, line: TactileLineSegment) {
        let milestones: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        for milestone in milestones {
            if abs(progress - milestone) < 0.05 && abs(progress - lastAnnouncedProgress) > 0.1 {
                lastAnnouncedProgress = progress
                
                var announcement = ""
                
                if milestone == 0.0 {
                    announcement = "Start of edge"
                } else if milestone == 0.5 {
                    announcement = "Middle of edge"
                } else if milestone == 1.0 {
                    announcement = "End of edge"
                } else if milestone == 0.25 {
                    announcement = "Quarter along edge"
                } else if milestone == 0.75 {
                    announcement = "Three quarters along edge"
                }
                
                if let label = line.associatedLabel, !label.isEmpty {
                    announcement += ", \(label)"
                }
                
                UIAccessibility.post(notification: .announcement, argument: announcement)
                break
            }
        }
    }
    
    private func handleTouchEnd() {
        currentTouch = nil
        activeHit = nil
        exploredPath = []
        lastAnnouncedProgress = -1
        haptics.stop()
    }
    
    /// Transform a point from canvas coordinates back to viewBox coordinates
    private func inverseTransformPoint(_ point: CGPoint) -> CGPoint {
        guard canvasSize.width > 0, canvasSize.height > 0,
              scene.viewBox.width > 0, scene.viewBox.height > 0 else {
            return point
        }
        
        // Same scale calculation as transformPoint
        let scaleX = canvasSize.width / scene.viewBox.width
        let scaleY = canvasSize.height / scene.viewBox.height
        let scale = min(scaleX, scaleY)
        
        // Same offset calculation
        let scaledWidth = scene.viewBox.width * scale
        let scaledHeight = scene.viewBox.height * scale
        let offsetX = (canvasSize.width - scaledWidth) / 2
        let offsetY = (canvasSize.height - scaledHeight) / 2
        
        // Inverse transform: (point - offset) / scale + viewBox.origin
        return CGPoint(
            x: (point.x - offsetX) / scale + scene.viewBox.origin.x,
            y: (point.y - offsetY) / scale + scene.viewBox.origin.y
        )
    }
    
    // MARK: - Announcements
    
    private func announceInitialDescription() {
        UIAccessibility.post(notification: .announcement, argument: accessibilityDescription)
    }
    
    private func announce(hit: HitResult) {
        let announcement = scene.announcement(for: hit)
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
}

// MARK: - Tactile Scene Hit Testing

extension TactileScene {
    func hitTest(at point: CGPoint, vertexThreshold: CGFloat = 20.0, lineThreshold: CGFloat = 25.0, labelThreshold: CGFloat = 30.0) -> HitResult? {
        var candidates: [HitResult] = []
        
        // PRIORITY 1: Check vertices first
        for vertex in vertices {
            let distance = vertex.distance(to: point)
            if distance <= vertexThreshold {
                candidates.append(HitResult(
                    primitive: .vertex(vertex),
                    type: .onVertex,
                    distance: distance,
                    point: point
                ))
            }
        }
        
        // PRIORITY 2: Check line segments
        if candidates.isEmpty {
            for line in lineSegments {
                let distance = line.distance(to: point)
                if distance <= lineThreshold {
                    candidates.append(HitResult(
                        primitive: .lineSegment(line),
                        type: .onLine,
                        distance: distance,
                        point: point
                    ))
                }
            }
        }
        
        // PRIORITY 3: Check if inside any polygon
        if candidates.isEmpty {
            for polygon in polygons {
                if polygon.contains(point) {
                    candidates.append(HitResult(
                        primitive: .polygon(polygon),
                        type: .insideShape,
                        distance: 0,
                        point: point
                    ))
                }
            }
        }
        
        // PRIORITY 4: Check labels
        if candidates.isEmpty {
            for label in labels {
                let distance = label.distance(to: point)
                if distance <= labelThreshold {
                    candidates.append(HitResult(
                        primitive: .label(label),
                        type: .onLabel,
                        distance: distance,
                        point: point
                    ))
                }
            }
        }
        
        return candidates.min(by: { $0.distance < $1.distance })
    }
    
    func announcement(for hit: HitResult) -> String {
        let isVoiceOverOn = UIAccessibility.isVoiceOverRunning
        
        switch hit.type {
        case .onLine:
            if case .lineSegment(let line) = hit.primitive {
                let label = line.associatedLabel ?? ""
                if !label.isEmpty {
                    return isVoiceOverOn ? "Edge, \(label)" : "\(label), edge"
                } else {
                    return "Edge"
                }
            }
            return "Edge"
            
        case .insideShape:
            if case .polygon(let polygon) = hit.primitive {
                let shapeName = polygon.shapeType
                let label = polygon.label ?? ""
                
                if !label.isEmpty {
                    return "Inside \(label), \(shapeName)"
                } else {
                    return "Inside \(shapeName)"
                }
            }
            return "Inside shape"
            
        case .onVertex:
            if case .vertex(let vertex) = hit.primitive {
                // Enhanced announcement for VoiceOver
                if isVoiceOverOn {
                    var desc = vertex.accessibilityDescription
                    // Add "ding" cue for VoiceOver users
                    return "\(desc). Ding."
                }
                return vertex.accessibilityDescription
            }
            return "Corner point"
            
        case .onLabel:
            if case .label(let label) = hit.primitive {
                return isVoiceOverOn ? "Measurement: \(label.text)" : "Label: \(label.text)"
            }
            return "Label"
        }
    }
}