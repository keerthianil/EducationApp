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
    @State private var lastAnnouncedProgress: CGFloat = -1 // Track progress announcements
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title is handled by DocumentSVGView, don't duplicate here
            ZStack(alignment: .topTrailing) {
                GeometryReader { geometry in
                    let actualSize = CGSize(width: geometry.size.width, height: geometry.size.height)
                    
                    ZStack {
                        // Visual rendering for sighted users
                        Canvas { context, size in
                        // Use the actual canvas size for rendering
                        let renderSize = size
                        
                        // Calculate scale for proper stroke width
                        // Ensure we use the actual viewBox dimensions
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
                            
                            // Scale stroke width to match view
                            let scaledStrokeWidth = max(1.0, line.strokeWidth * scale)
                            
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
                        
                        // Draw vertices as small circles
                        let vertexRadius = max(2.0, 3.0 * scale)
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
                        
                        // Draw labels (for visual reference)
                        // Use larger font size for better visibility
                        let fontSize = max(12.0, 14.0 * scale)
                        for label in scene.labels {
                            let transformedPos = transformPoint(label.position, size: renderSize)
                            // Only draw if within bounds
                            if transformedPos.x >= 0 && transformedPos.x <= renderSize.width &&
                               transformedPos.y >= 0 && transformedPos.y <= renderSize.height {
                                context.draw(
                                    Text(label.text)
                                        .font(.custom("Arial", size: fontSize).weight(.medium))
                                        .foregroundColor(.black),
                                    at: transformedPos,
                                    anchor: .center
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: geometry.size.height)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Invisible touch overlay - use binding for coordinate transformation
                    // Disable touch processing when sheet is open or double-tap is being processed
                    if !showMultisensoryView && !isProcessingDoubleTap {
                        TactileTouchOverlay(
                            viewBox: scene.viewBox,
                            canvasSize: $canvasSize,
                            onTouch: handleTouch,
                            onDrag: handleDrag,
                            onEnd: handleTouchEnd
                        )
                        .allowsHitTesting(true) // Ensure touches are received
                    }
                    
                    // Double-tap gesture overlay - separate from touch overlay
                    // This must be on top of TactileTouchOverlay to receive double-taps
                    Color.clear
                        .contentShape(Rectangle())
                        .allowsHitTesting(!showMultisensoryView && !isProcessingDoubleTap)
                        .highPriorityGesture(
                            TapGesture(count: 2)
                                .onEnded { _ in
                                    // Double-tap to open multisensory view
                                    // Prevent any other gestures from interfering
                                    guard !showMultisensoryView && !isProcessingDoubleTap else { return }
                                    
                                    isProcessingDoubleTap = true
                                    UISelectionFeedbackGenerator().selectionChanged()
                                    
                                    // Set sheet to open after a brief delay to ensure gesture is processed
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        showMultisensoryView = true
                                        // Reset flag after sheet opens
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                            isProcessingDoubleTap = false
                                        }
                                    }
                                }
                        )
                    }
                    .onAppear {
                        canvasSize = actualSize
                    }
                    .onChange(of: geometry.size) { newSize in
                        // Update canvas size for touch overlay coordinate transformation
                        canvasSize = CGSize(width: newSize.width, height: newSize.height)
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(scene.viewBox.size, contentMode: .fit)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint("Double tap to open multisensory exploration view")
                
                // Button to open multisensory view (alternative to double-tap)
                Button {
                    guard !showMultisensoryView else { return }
                    UISelectionFeedbackGenerator().selectionChanged()
                    isProcessingDoubleTap = true
                    showMultisensoryView = true
                    // Reset flag
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
                .accessibilityLabel("Open multisensory exploration view")
            }
        }
        .onAppear {
            announceInitialDescription()
            // Prepare haptics for VoiceOver compatibility
            haptics.prepare()
        }
        .fullScreenCover(isPresented: $showMultisensoryView) {
            MultisensoryTactileView(scene: scene, title: title, summaries: summaries)
                .onAppear {
                    print("📱 Multisensory view appeared")
                }
                .onDisappear {
                    print("📱 Multisensory view disappeared")
                }
        }
        .onChange(of: showMultisensoryView) { newValue in
            print("📱 Sheet state: \(newValue)")
        }
    }
    
    // MARK: - Coordinate Transformation
    
    private func transformPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        guard scene.viewBox.width > 0 && scene.viewBox.height > 0 else {
            return point
        }
        
        // Calculate uniform scale to fit viewBox in available size
        let scaleX = size.width / scene.viewBox.width
        let scaleY = size.height / scene.viewBox.height
        let scale = min(scaleX, scaleY)
        
        // Center the content
        let scaledWidth = scene.viewBox.width * scale
        let scaledHeight = scene.viewBox.height * scale
        let offsetX = (size.width - scaledWidth) / 2
        let offsetY = (size.height - scaledHeight) / 2
        
        // Transform: subtract viewBox origin, scale, add offset
        return CGPoint(
            x: (point.x - scene.viewBox.origin.x) * scale + offsetX,
            y: (point.y - scene.viewBox.origin.y) * scale + offsetY
        )
    }
    
    // MARK: - Touch Handling (Nav_Indoor pattern)
    
    private func handleTouch(at point: CGPoint) {
        let svgPoint = inverseTransformPoint(point)
        currentTouch = svgPoint
        exploredPath = [svgPoint]
        
        // Hit-test with priority (vertices > lines > polygons)
        if let hit = scene.hitTest(at: svgPoint) {
            activeHit = hit
            haptics.play(for: hit.type)
            announce(hit: hit)
            
            // If touching a line, start continuous haptics immediately
            if hit.type == .onLine {
                haptics.continuous()
            }
        } else {
            activeHit = nil
            haptics.stop()
        }
    }
    
    private func handleDrag(from: CGPoint, to: CGPoint) {
        let svgFrom = inverseTransformPoint(from)
        let svgTo = inverseTransformPoint(to)
        
        exploredPath.append(svgTo)
        currentTouch = svgTo
        
        // Hit-test with priority
        if let hit = scene.hitTest(at: svgTo) {
            // Check if we crossed a boundary (different primitive)
            let previousId = activeHit?.primitive.id
            let currentId = hit.primitive.id
            
            if previousId != currentId {
                // Crossed boundary - pulse and announce
                haptics.pulse()
                activeHit = hit
                haptics.play(for: hit.type)
                announce(hit: hit)
                lastAnnouncedProgress = -1 // Reset progress tracking
                
                // If new element is a line, start continuous haptics
                if hit.type == .onLine {
                    haptics.continuous()
                }
            } else {
                // Moving along same element
                if hit.type == .onLine {
                    // Continuous vibration while dragging along line
                    haptics.continuous()
                    
                    // Track progress along line and announce milestones
                    if case .lineSegment(let line) = hit.primitive {
                        let progress = line.progressAlongLine(point: svgTo)
                        announceProgress(progress: progress, line: line)
                    }
                } else if hit.type == .onVertex {
                    // On vertex - keep pulsing
                    haptics.pulse()
                }
            }
        } else {
            // Moved to empty space - stop haptics
            haptics.stop()
            activeHit = nil
            lastAnnouncedProgress = -1
        }
    }
    
    // Announce progress milestones along a line (start, middle, end, measurements)
    private func announceProgress(progress: CGFloat, line: TactileLineSegment) {
        // Only announce at specific milestones to avoid too many announcements
        let milestones: [CGFloat] = [0.0, 0.25, 0.5, 0.75, 1.0]
        
        // Check if we're near a milestone (within 5% tolerance)
        for milestone in milestones {
            if abs(progress - milestone) < 0.05 && abs(progress - lastAnnouncedProgress) > 0.1 {
                lastAnnouncedProgress = progress
                
                var announcement = ""
                
                // Determine position
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
                
                // Add measurement if available
                if let label = line.associatedLabel, !label.isEmpty {
                    announcement += ", \(label)"
                } else {
                    // Announce length if no label
                    let length = line.length
                    if length > 0 {
                        announcement += ", length \(String(format: "%.0f", length)) points"
                    }
                }
                
                // Announce via VoiceOver
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
    
    private func inverseTransformPoint(_ point: CGPoint) -> CGPoint {
        guard canvasSize.width > 0 && canvasSize.height > 0,
              scene.viewBox.width > 0 && scene.viewBox.height > 0 else {
            return point
        }
        
        let scaleX = canvasSize.width / scene.viewBox.width
        let scaleY = canvasSize.height / scene.viewBox.height
        let scale = min(scaleX, scaleY)
        
        let scaledWidth = scene.viewBox.width * scale
        let scaledHeight = scene.viewBox.height * scale
        let offsetX = (canvasSize.width - scaledWidth) / 2
        let offsetY = (canvasSize.height - scaledHeight) / 2
        
        // Inverse transform: subtract offset, divide by scale, add viewBox origin
        return CGPoint(
            x: (point.x - offsetX) / scale + scene.viewBox.origin.x,
            y: (point.y - offsetY) / scale + scene.viewBox.origin.y
        )
    }
    
    // MARK: - Announcements
    
    private func announceInitialDescription() {
        let description = summaries?.first ?? title ?? "Geometric diagram"
        UIAccessibility.post(notification: .announcement, argument: description)
    }
    
    private func announce(hit: HitResult) {
        let announcement = scene.announcement(for: hit)
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
    
    private var accessibilityLabel: String {
        if let t = title {
            return t
        }
        if let summary = summaries?.first {
            return summary
        }
        return "Geometric diagram"
    }
}

// MARK: - Tactile Scene Hit Testing (Nav_Indoor pattern with priority)

extension TactileScene {
    // Hit-test with priority: vertices > lines > polygons > labels
    // Uses larger thresholds for better touch detection
    func hitTest(at point: CGPoint, vertexThreshold: CGFloat = 20.0, lineThreshold: CGFloat = 25.0, labelThreshold: CGFloat = 30.0) -> HitResult? {
        var candidates: [HitResult] = []
        
        // PRIORITY 1: Check vertices first (most specific, highest priority)
        // Vertices should be detected before lines they're on
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
        
        // PRIORITY 2: Check line segments (corridors/edges)
        // Only if not already on a vertex
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
        // Only if not on vertex or line
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
        
        // PRIORITY 4: Check labels (lowest priority)
        // Only if nothing else hit
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
        
        // Return closest hit (prioritized by order above)
        return candidates.min(by: { $0.distance < $1.distance })
    }
    
    func announcement(for hit: HitResult) -> String {
        switch hit.type {
        case .onLine:
            if case .lineSegment(let line) = hit.primitive {
                let label = line.associatedLabel ?? ""
                // Format length in a more natural way
                let length = line.length
                let lengthText: String
                if length < 50 {
                    lengthText = String(format: "%.0f points", length)
                } else {
                    lengthText = String(format: "%.0f points long", length)
                }
                
                if !label.isEmpty {
                    return "\(label), edge, \(lengthText)"
                } else {
                    return "Edge, \(lengthText)"
                }
            }
            return "Edge"
            
        case .insideShape:
            if case .polygon(let polygon) = hit.primitive {
                let sides = polygon.sideCount
                let label = polygon.label ?? ""
                
                // More descriptive shape names
                let shapeName: String
                switch sides {
                case 3: shapeName = "triangle"
                case 4: shapeName = "square or rectangle"
                case 5: shapeName = "pentagon"
                case 6: shapeName = "hexagon"
                default: shapeName = "\(sides)-sided polygon"
                }
                
                if !label.isEmpty {
                    return "Inside \(label), \(shapeName)"
                } else {
                    return "Inside \(shapeName)"
                }
            }
            return "Inside shape"
            
        case .onVertex:
            // Vertex/intersection - important landmark
            return "Corner point, intersection"
            
        case .onLabel:
            if case .label(let label) = hit.primitive {
                return "Label: \(label.text)"
            }
            return "Label"
        }
    }
}
