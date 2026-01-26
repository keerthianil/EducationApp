//
//  MultisensoryTactileView.swift
//
//  Full-screen multisensory tactile exploration view with enhanced rendering and audio feedback

import SwiftUI
import UIKit
import AVFoundation
import AudioToolbox

struct MultisensoryTactileView: View {
    let scene: TactileScene
    let title: String?
    let summaries: [String]?
    
    @Environment(\.dismiss) private var dismiss
    @State private var isVoiceOverOn = false
    @State private var currentTouch: CGPoint?
    @State private var activeHit: HitResult?
    @State private var exploredPath: [CGPoint] = []
    @State private var canvasSize: CGSize = .zero
    @State private var haptics = TactileHapticEngine()
    
    // Enhanced rendering parameters for multisensory mode
    private let thickLineWidth: CGFloat = 4.0
    private let vertexRadius: CGFloat = 8.0
    private let lineWidthMultiplier: CGFloat = 2.5
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                // Header with title
                if let t = title {
                    HStack {
                        Text(t)
                            .font(.custom("Arial", size: 22).weight(.bold))
                            .foregroundColor(Color(hex: "#121417"))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                }
                
                // Multisensory canvas
                GeometryReader { geometry in
                    let actualSize = CGSize(width: geometry.size.width, height: geometry.size.height)
                    
                    ZStack {
                        // Enhanced visual rendering with thicker lines
                        Canvas { context, size in
                            let renderSize = CGSize(width: min(size.width, geometry.size.width),
                                                   height: min(size.height, geometry.size.height))
                            
                            let scaleX = renderSize.width / max(scene.viewBox.width, 1)
                            let scaleY = renderSize.height / max(scene.viewBox.height, 1)
                            let scale = min(scaleX, scaleY)
                            
                            // Draw all line segments with THICK borders
                            for line in scene.lineSegments {
                                var path = Path()
                                let start = transformPoint(line.start, size: renderSize)
                                let end = transformPoint(line.end, size: renderSize)
                                path.move(to: start)
                                path.addLine(to: end)
                                
                                let scaledStrokeWidth = max(thickLineWidth, line.strokeWidth * scale * lineWidthMultiplier)
                                
                                context.stroke(
                                    path,
                                    with: .color(.black),
                                    lineWidth: scaledStrokeWidth
                                )
                            }
                            
                            // Fill polygons
                            for polygon in scene.polygons {
                                if polygon.interior && !polygon.boundary.isEmpty {
                                    var path = Path()
                                    let firstPoint = transformPoint(polygon.boundary[0], size: renderSize)
                                    path.move(to: firstPoint)
                                    for point in polygon.boundary.dropFirst() {
                                        path.addLine(to: transformPoint(point, size: renderSize))
                                    }
                                    path.closeSubpath()
                                    
                                    context.fill(path, with: .color(.gray.opacity(0.15)))
                                    context.stroke(path, with: .color(.gray.opacity(0.5)), lineWidth: thickLineWidth)
                                }
                            }
                            
                            // Draw vertices as LARGE circles
                            let scaledVertexRadius = max(vertexRadius, vertexRadius * scale)
                            for vertex in scene.vertices {
                                var path = Path()
                                let center = transformPoint(vertex.position, size: renderSize)
                                path.addEllipse(in: CGRect(
                                    x: center.x - scaledVertexRadius,
                                    y: center.y - scaledVertexRadius,
                                    width: scaledVertexRadius * 2,
                                    height: scaledVertexRadius * 2
                                ))
                                context.fill(path, with: .color(.black))
                            }
                            
                            // Draw labels (larger font)
                            let fontSize = max(14.0, 16.0 * scale)
                            for label in scene.labels {
                                context.draw(
                                    Text(label.text)
                                        .font(.custom("Arial", size: fontSize).weight(.medium))
                                        .foregroundColor(.black),
                                    at: transformPoint(label.position, size: renderSize),
                                    anchor: .center
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(scene.viewBox.size, contentMode: .fit)
                        
                        // Full-screen touch overlay
                        TactileTouchOverlay(
                            viewBox: scene.viewBox,
                            canvasSize: $canvasSize,
                            onTouch: handleTouch,
                            onDrag: handleDrag,
                            onEnd: handleTouchEnd
                        )
                        // Add accessibility gesture for VoiceOver users
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Tactile graphic exploration area")
                        .accessibilityHint("Touch and drag to explore the graphic. Corners will make a sound when touched.")
                        .accessibilityAddTraits(.allowsDirectInteraction)
                    }
                    .onAppear {
                        canvasSize = actualSize
                    }
                    .onChange(of: geometry.size) { newSize in
                        canvasSize = CGSize(width: newSize.width, height: newSize.height)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Instructions footer
                Text("Touch and explore the shape. Corners will make a sound when touched.")
                    .font(.custom("Arial", size: 14))
                    .foregroundColor(Color(hex: "#6B7280"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        haptics.stop()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(hex: "#47494F"))
                    }
                    .accessibilityLabel("Close multisensory view")
                }
            }
        }
        .onAppear {
            isVoiceOverOn = UIAccessibility.isVoiceOverRunning
            // Prepare haptics immediately and repeatedly for VoiceOver
            haptics.prepare()
            if isVoiceOverOn {
                // Re-prepare every second when VoiceOver is on
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    haptics.prepare()
                }
            }
            announceInitialDescription()
        }
        .onDisappear {
            haptics.stop()
        }
        .onChange(of: UIAccessibility.isVoiceOverRunning) { newValue in
            isVoiceOverOn = newValue
            if newValue {
                haptics.prepare()
            }
        }
    }
    
    // MARK: - Coordinate Transformation
    
    /// Transform a point from viewBox coordinates to canvas coordinates
    private func transformPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        guard scene.viewBox.width > 0 && scene.viewBox.height > 0 else {
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
        
        #if DEBUG
        print("[Multisensory] Touch at: \(point), VoiceOver: \(isVoiceOverOn)")
        #endif
        
        // Use larger threshold when VoiceOver is on for easier detection
        let vertexThreshold: CGFloat = isVoiceOverOn ? 35.0 : 20.0
        let lineThreshold: CGFloat = isVoiceOverOn ? 40.0 : 25.0
        
        if let hit = scene.hitTest(at: svgPoint, vertexThreshold: vertexThreshold, lineThreshold: lineThreshold) {
            activeHit = hit
            
            #if DEBUG
            print("[Multisensory] Hit detected: \(hit.type), VoiceOver: \(isVoiceOverOn)")
            #endif
            
            // Always prepare and play immediately - no delays
            haptics.prepare()
            haptics.play(for: hit.type)
            
            // Always play ding for vertices, especially with VoiceOver
            if hit.type == .onVertex {
                playDingSound()
                // With VoiceOver, give extra time for announcement
                if isVoiceOverOn {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.announce(hit: hit)
                    }
                } else {
                    announce(hit: hit)
                }
            } else {
                if isVoiceOverOn {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.announce(hit: hit)
                    }
                } else {
                    announce(hit: hit)
                }
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
        
        // Use larger threshold when VoiceOver is on
        let vertexThreshold: CGFloat = isVoiceOverOn ? 35.0 : 20.0
        let lineThreshold: CGFloat = isVoiceOverOn ? 40.0 : 25.0
        
        if let hit = scene.hitTest(at: svgTo, vertexThreshold: vertexThreshold, lineThreshold: lineThreshold) {
            if activeHit?.primitive.id != hit.primitive.id {
                activeHit = hit
                
                // Always prepare and play immediately
                haptics.prepare()
                haptics.pulse()
                haptics.play(for: hit.type)
                
                // Always play ding for vertices
                if hit.type == .onVertex {
                    playDingSound()
                    // With VoiceOver, delay announcement slightly to let ding play
                    if isVoiceOverOn {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.announce(hit: hit)
                        }
                    } else {
                        announce(hit: hit)
                    }
                } else {
                    if isVoiceOverOn {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.announce(hit: hit)
                        }
                    } else {
                        announce(hit: hit)
                    }
                }
            } else {
                // Continue haptics for lines
                if hit.type == .onLine {
                    haptics.continuous()
                } else if hit.type == .onVertex {
                    // Re-trigger ding if staying on vertex
                    if isVoiceOverOn {
                        haptics.prepare()
                    }
                    haptics.pulse()
                }
            }
        } else {
            haptics.stop()
            activeHit = nil
        }
    }
    
    private func handleTouchEnd() {
        currentTouch = nil
        activeHit = nil
        exploredPath = []
        haptics.stop()
    }
    
    /// Transform a point from canvas coordinates back to viewBox coordinates
    private func inverseTransformPoint(_ point: CGPoint) -> CGPoint {
        guard canvasSize.width > 0 && canvasSize.height > 0,
              scene.viewBox.width > 0 && scene.viewBox.height > 0 else {
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
    
    // MARK: - Audio Feedback
    
    private func playDingSound() {
        // Always play ding sound, especially important with VoiceOver
        AudioServicesPlaySystemSound(1057)
        // Play haptics immediately - no delays
        haptics.prepare()
        haptics.pulse()
        // Double pulse for better detection with VoiceOver
        if isVoiceOverOn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.haptics.prepare()
                self.haptics.pulse()
            }
        }
    }
    
    // MARK: - Announcements
    
    private func announceInitialDescription() {
        let description = summaries?.first ?? title ?? "Multisensory tactile exploration"
        if isVoiceOverOn {
            // Delay slightly to ensure view is fully loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIAccessibility.post(notification: .screenChanged, argument: description)
            }
        } else {
            UIAccessibility.post(notification: .announcement, argument: description)
        }
    }
    
    private func announce(hit: HitResult) {
        guard isVoiceOverOn else { return }
        
        let announcement = scene.announcement(for: hit)
        
        // For vertices, make announcement more prominent
        if hit.type == .onVertex {
            // Use screen notification for vertices (more prominent)
            UIAccessibility.post(notification: .screenChanged, argument: announcement)
            // Also post announcement for redundancy
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIAccessibility.post(notification: .announcement, argument: announcement)
            }
        } else {
            // Regular announcement for other elements
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }
}