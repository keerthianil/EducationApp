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
    @State private var currentTouch: CGPoint?
    @State private var activeHit: HitResult?
    @State private var exploredPath: [CGPoint] = []
    @State private var canvasSize: CGSize = .zero
    @State private var haptics = TactileHapticEngine()
    @State private var audioPlayer: AVAudioPlayer?
    
    // Enhanced rendering parameters for multisensory mode
    private let thickLineWidth: CGFloat = 4.0  // Thicker borders
    private let vertexRadius: CGFloat = 8.0    // Larger vertices
    private let lineWidthMultiplier: CGFloat = 2.5  // Make lines much thicker
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with title and close button
                HStack {
                    if let t = title {
                        Text(t)
                            .font(.custom("Arial", size: 22).weight(.bold))
                            .foregroundColor(Color(hex: "#121417"))
                    }
                    
                    Spacer()
                    
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
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // Multisensory canvas
                GeometryReader { geometry in
                    let actualSize = CGSize(width: geometry.size.width, height: geometry.size.height)
                    
                    ZStack {
                        // Enhanced visual rendering with thicker lines
                        Canvas { context, size in
                            let renderSize = CGSize(width: min(size.width, geometry.size.width), 
                                                   height: min(size.height, geometry.size.height))
                            
                            let scaleX = renderSize.width / scene.viewBox.width
                            let scaleY = renderSize.height / scene.viewBox.height
                            let scale = min(scaleX, scaleY)
                            
                            // Draw all line segments with THICK borders
                            for line in scene.lineSegments {
                                var path = Path()
                                let start = transformPoint(line.start, size: renderSize)
                                let end = transformPoint(line.end, size: renderSize)
                                path.move(to: start)
                                path.addLine(to: end)
                                
                                // Much thicker stroke width for tactile exploration
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
                            
                            // Draw vertices as LARGE circles (easier to feel)
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
                Text("Touch and explore the shape. Vertices will make a sound when touched.")
                    .font(.custom("Arial", size: 14))
                    .foregroundColor(Color(hex: "#6B7280"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
        }
        .onAppear {
            announceInitialDescription()
            setupAudioPlayer()
        }
        .onDisappear {
            haptics.stop()
            audioPlayer?.stop()
            print("📱 Multisensory view onDisappear called")
        }
        .onChange(of: scene.id) { _ in
            // Prevent dismissal if scene changes
        }
    }
    
    // MARK: - Coordinate Transformation
    
    private func transformPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        guard scene.viewBox.width > 0 && scene.viewBox.height > 0 else {
            return point
        }
        
        let scaleX = size.width / scene.viewBox.width
        let scaleY = size.height / scene.viewBox.height
        let scale = min(scaleX, scaleY)
        
        let scaledWidth = scene.viewBox.width * scale
        let scaledHeight = scene.viewBox.height * scale
        let offsetX = (size.width - scaledWidth) / 2
        let offsetY = (size.height - scaledHeight) / 2
        
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
            
            // Play audio "ding" for vertices
            if hit.type == .onVertex {
                playDingSound()
            }
            
            announce(hit: hit)
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
        
        if let hit = scene.hitTest(at: svgTo) {
            if activeHit?.primitive.id != hit.primitive.id {
                // Crossed boundary
                haptics.pulse()
                activeHit = hit
                
                // Play ding for vertices
                if hit.type == .onVertex {
                    playDingSound()
                }
                
                announce(hit: hit)
            } else {
                // Moving along same element
                haptics.continuous()
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
        
        return CGPoint(
            x: (point.x - offsetX) / scale + scene.viewBox.origin.x,
            y: (point.y - offsetY) / scale + scene.viewBox.origin.y
        )
    }
    
    // MARK: - Audio Feedback
    
    private func setupAudioPlayer() {
        // Create a "ding" sound using system audio
        // Using a simple sine wave tone as a ding sound
        guard let url = createDingSound() else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
        } catch {
            print("⚠️ Failed to setup audio player: \(error)")
        }
    }
    
    private func createDingSound() -> URL? {
        // Create a temporary audio file with a "ding" tone
        // Using system sound ID for a simple ding
        return nil  // We'll use AudioServicesPlaySystemSound instead
    }
    
    private func playDingSound() {
        // Play system sound - using a pleasant ding tone (1057 is a nice "peek" sound)
        AudioServicesPlaySystemSound(1057)
        
        // Also provide haptic feedback
        haptics.pulse()
    }
    
    // MARK: - Announcements
    
    private func announceInitialDescription() {
        let description = summaries?.first ?? title ?? "Multisensory tactile exploration"
        UIAccessibility.post(notification: .announcement, argument: description)
    }
    
    private func announce(hit: HitResult) {
        let announcement = scene.announcement(for: hit)
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}