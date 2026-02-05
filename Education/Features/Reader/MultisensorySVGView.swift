//
//  MultisensorySVGView.swift
//  Education
//
//  Created for blind and low-vision users to explore graphics through touch and haptics
//

import SwiftUI
import UIKit
import AVFoundation
import AudioToolbox
import CoreHaptics

/// Multisensory view: figure only. User touches and feels the shape.
/// - VoiceOver on enter: "You are in the multisensory view. You can touch and feel the figure."
/// - Lines: continuous haptics while tracing; dimension announced with pause (only if label exists)
/// - Vertices: ding sound when touched
/// - Line width: 4 mm
/// - Three-finger swipe to go back
struct MultisensorySVGView: View {
    let graphicData: [String: Any]
    let title: String?
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    
    var body: some View {
        GeometryReader { geometry in
            MultisensorySVGViewRepresentable(graphicData: graphicData, haptics: haptics, speech: speech, onDismiss: { dismiss() })
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // Fill fullScreenCover so geometry is full screen
        .ignoresSafeArea()
            .accessibilityAction(.escape) {
                dismiss()
            }
            .onAppear {
                // Delay so VoiceOver finishes the view's accessibility label first and announcements don't overlap
                let message = "You are in the multisensory view. You can touch and feel the figure."
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                    UIAccessibility.post(notification: .announcement, argument: message)
                }
            }
    }
}

// MARK: - UIViewRepresentable

struct MultisensorySVGViewRepresentable: UIViewRepresentable {
    let graphicData: [String: Any]
    let haptics: HapticService
    let speech: SpeechService?
    let onDismiss: () -> Void
    
    func makeUIView(context: Context) -> MultisensoryCanvasView {
        let view = MultisensoryCanvasView()
        view.graphicData = graphicData
        view.haptics = haptics
        view.speech = speech
        view.onDismiss = onDismiss
        view.setupGestures()
        return view
    }
    
    func updateUIView(_ uiView: MultisensoryCanvasView, context: Context) {
        uiView.graphicData = graphicData
        uiView.haptics = haptics
        uiView.speech = speech
        uiView.onDismiss = onDismiss
        validateGraphicDataMeasurements(graphicData, figureSummary: nil)
        uiView.setNeedsDisplay()
    }
}

// Line width: 4 mm using device-specific PPI for accurate physical measurement
private var strokeWidth4mm: CGFloat {
    PhysicalDimensions.mmToPoints(4.0)
}

// MARK: - JSON validation (measurement / label mapping)
//
// Height line in svgContent: To show height as dashed in the SVG but still have tactile line detection,
// add the height segment in graphicData.lines[] with id "line_height" and the measurement as label.
// In svgContent you can draw the same segment with stroke-dasharray (e.g. stroke-dasharray="6,4") so it
// appears dashed visually; the app uses only graphicData.lines[] for drawing and touch, so the dashed
// style is purely visual if you also render from graphicData in the reader.
//
/// Logs warnings if measurement labels in labels[] don't map to lines with non-empty label, or if doc claims "base and height" but only one line has label.
func validateGraphicDataMeasurements(_ graphicData: [String: Any], figureSummary: String? = nil) {
    guard let labels = graphicData["labels"] as? [[String: Any]],
          let lineData = graphicData["lines"] as? [[String: Any]] else { return }
    
    let lineIdsToIndex: [String: Int] = Dictionary(uniqueKeysWithValues: lineData.enumerated().compactMap { i, line in
        guard let id = line["id"] as? String else { return nil }
        return (id, i)
    })
    
    for label in labels {
        guard let text = label["text"] as? String else { continue }
        let looksLikeMeasurement = text.contains("ft") || text.contains("yd") || text.contains("in")
        guard looksLikeMeasurement else { continue }
        
        guard let forLineId = label["forLine"] as? String else { continue }
        guard let lineIndex = lineIdsToIndex[forLineId],
              lineIndex < lineData.count else { continue }
        
        let line = lineData[lineIndex]
        let lineLabel = line["label"] as? String
        if lineLabel == nil || lineLabel?.isEmpty == true {
            print("⚠️ [graphicData] Measurement label \"\(text)\" has forLine=\"\(forLineId)\", but that line has no label. Touch-announce will not work. Add label to lines[] for \"\(forLineId)\".")
        }
    }
    
    if let summary = figureSummary, (summary.lowercased().contains("base") && summary.lowercased().contains("height") && summary.lowercased().contains("label")) {
        let labeledCount = lineData.filter { line in
            guard let l = line["label"] as? String else { return false }
            return !l.isEmpty
        }.count
        if labeledCount < 2 {
            print("⚠️ [graphicData] Summary says base and height are labeled, but only \(labeledCount) line(s) have non-empty label. Add a line_height (and label) for height.")
        }
    }
}

/// A dot on a labeled line (at midpoint) that announces the dimension when touched; repeatable with cooldown.
struct DimensionDot {
    let point: CGPoint
    let lineIndex: Int
    let label: String
}

// MARK: - Canvas View

class MultisensoryCanvasView: UIView {
    var graphicData: [String: Any] = [:]
    var haptics: HapticService?
    var speech: SpeechService?
    var onDismiss: (() -> Void)?
    
    private var lines: [(start: CGPoint, end: CGPoint, label: String?)] = []
    private var vertices: [CGPoint] = []
    private var dimensionDots: [DimensionDot] = []
    private var viewBox: (x: Double, y: Double, width: Double, height: Double) = (0, 0, 448, 380)
    /// Tight bounding box of actual content (lines + vertices + labels); used for scaling so figure fills screen
    private var contentBox: (minX: Double, minY: Double, width: Double, height: Double) = (0, 0, 1, 1)
    
    private var activeLineIndex: Int? = nil
    private var lastAnnouncedLineIndex: Int? = nil
    private var continuousHapticTimer: Timer?
    private var dimensionAnnounceTimer: Timer?
    
    // Core Haptics for VoiceOver compatibility
    private var hapticEngine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    
    // Track if we already played ding for current vertex touch
    private var lastVertexIndex: Int? = nil
    
    /// When user is touching a dimension dot, we suppress the delayed line announcement to avoid double-speak.
    private var activeDimensionDotIndex: Int? = nil
    
    /// When true, draw a thin red outline around dot hit areas for debugging.
    private let debugDrawDotOutlines = false
    
    /// Dot radii (used for drawing and hit testing). Min 10pt so visibly large.
    private var vertexDotRadius: CGFloat { max(PhysicalDimensions.mmToPoints(6.0) / 2, 10) }
    private var dimensionDotRadius: CGFloat { max(PhysicalDimensions.mmToPoints(6.0) / 2, 10) }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        
        // CRITICAL FOR VOICEOVER: Make this view allow direct touch interaction
        isAccessibilityElement = true
        accessibilityTraits = [.allowsDirectInteraction]
        accessibilityLabel = "Tactile figure. Explore by touch."
        
        setupHapticEngine()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Core Haptics Setup (Works with VoiceOver)
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.isAutoShutdownEnabled = false
            hapticEngine?.playsHapticsOnly = true
            
            // Handle engine reset
            hapticEngine?.resetHandler = { [weak self] in
                do {
                    try self?.hapticEngine?.start()
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
            
            // Handle engine stop
            hapticEngine?.stoppedHandler = { [weak self] reason in
                print("Haptic engine stopped: \(reason.rawValue)")
                do {
                    try self?.hapticEngine?.start()
                } catch {
                    print("Failed to restart haptic engine: \(error)")
                }
            }
            
            try hapticEngine?.start()
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    private func ensureHapticEngineRunning() {
        guard let engine = hapticEngine else { return }
        do {
            try engine.start()
        } catch {
            print("Failed to start haptic engine: \(error)")
        }
    }
    
    func setupGestures() {
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
        
        // Three-finger swipe to go back
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipe(_:)))
        swipeRight.direction = .right
        swipeRight.numberOfTouchesRequired = 3
        addGestureRecognizer(swipeRight)
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipe(_:)))
        swipeLeft.direction = .left
        swipeLeft.numberOfTouchesRequired = 3
        addGestureRecognizer(swipeLeft)
    }
    
    @objc private func handleThreeFingerSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.state == .recognized {
            stopAllFeedback()
            onDismiss?()
        }
    }
    
    // MARK: - Direct Touch Handling (Works with VoiceOver due to allowsDirectInteraction)
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        
        // Ensure haptic engine is running
        ensureHapticEngineRunning()
        
        handleTouchAt(point)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        handleTouchAt(point)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        stopAllFeedback()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        stopAllFeedback()
    }
    
    // MARK: - Drawing
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Use the actual drawing rect (not bounds) to ensure accurate scaling
        parseAndCalculateElements(drawingRect: rect)
        
        // Draw lines with 4mm stroke width
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(strokeWidth4mm)
        
        for line in lines {
            context.move(to: line.start)
            context.addLine(to: line.end)
            context.strokePath()
        }
        
        // Draw dots AFTER lines so they appear on top. Red, visibly large.
        // Vertex dots (red)
        context.setFillColor(UIColor.systemRed.cgColor)
        for vertex in vertices {
            let r = vertexDotRadius
            context.fillEllipse(in: CGRect(x: vertex.x - r, y: vertex.y - r, width: r * 2, height: r * 2))
            if debugDrawDotOutlines {
                context.setStrokeColor(UIColor.systemRed.cgColor)
                context.setLineWidth(1)
                context.strokeEllipse(in: CGRect(x: vertex.x - r, y: vertex.y - r, width: r * 2, height: r * 2))
            }
        }
        
        // Dimension dots (red) on labeled sides
        context.setFillColor(UIColor.systemRed.cgColor)
        for dot in dimensionDots {
            let r = dimensionDotRadius
            context.fillEllipse(in: CGRect(x: dot.point.x - r, y: dot.point.y - r, width: r * 2, height: r * 2))
            if debugDrawDotOutlines {
                context.setStrokeColor(UIColor.systemRed.cgColor)
                context.setLineWidth(1)
                context.strokeEllipse(in: CGRect(x: dot.point.x - r, y: dot.point.y - r, width: r * 2, height: r * 2))
            }
        }
        
        // Draw dimension labels (use same rect as drawing)
        drawLabels(context: context, drawingRect: rect)
    }
    
    private func drawLabels(context: CGContext, drawingRect: CGRect) {
        let padding: CGFloat = max(4, strokeWidth4mm / 2 + 2)
        let availableWidth = max(drawingRect.width, 100)
        let availableHeight = max(drawingRect.height, 100)
        let drawableWidth = availableWidth - (padding * 2)
        let drawableHeight = availableHeight - (padding * 2)
        
        guard contentBox.width > 0 && contentBox.height > 0, drawableWidth > 0, drawableHeight > 0 else { return }
        
        let scaleX = drawableWidth / contentBox.width
        let scaleY = drawableHeight / contentBox.height
        let scale = min(scaleX, scaleY)
        
        let scaledWidth = contentBox.width * scale
        let scaledHeight = contentBox.height * scale
        let offsetX = padding + (drawableWidth - scaledWidth) / 2
        let offsetY = padding + (drawableHeight - scaledHeight) / 2
        
        if let labelData = graphicData["labels"] as? [[String: Any]] {
            for label in labelData {
                guard let x = Self._double(label["x"]), let y = Self._double(label["y"]),
                      let text = label["text"] as? String else { continue }
                
                let fontSize = (label["fontSize"] as? Int) ?? 15
                let scaledFontSize = max(CGFloat(fontSize) * scale, 12)
                
                var point = CGPoint(
                    x: offsetX + CGFloat((x - contentBox.minX) * scale),
                    y: offsetY + CGFloat((y - contentBox.minY) * scale)
                )
                
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: scaledFontSize),
                    .foregroundColor: UIColor.black
                ]
                
                // Calculate text size for centering and bounds checking
                let textSize = (text as NSString).size(withAttributes: attributes)
                
                // Adjust position to keep text within bounds
                let minX = padding
                let maxX = drawingRect.width - padding - textSize.width
                let minY = padding
                let maxY = drawingRect.height - padding - textSize.height
                
                point.x = max(minX, min(maxX, point.x - textSize.width / 2))
                point.y = max(minY, min(maxY, point.y - textSize.height / 2))
                
                // Draw white background for better readability
                let bgRect = CGRect(
                    x: point.x - 2,
                    y: point.y - 1,
                    width: textSize.width + 4,
                    height: textSize.height + 2
                )
                context.setFillColor(UIColor.white.cgColor)
                context.fill(bgRect)
                
                // Draw the text
                let attributedString = NSAttributedString(string: text, attributes: attributes)
                attributedString.draw(at: point)
            }
        }
    }
    
    // MARK: - Parsing
    
    /// Extracts a numeric value as Double from JSON (NSNumber or Double).
    private static func _double(_ value: Any?) -> Double? {
        guard let v = value else { return nil }
        if let n = v as? NSNumber { return n.doubleValue }
        if let d = v as? Double { return d }
        return nil
    }
    
    /// Tight bounding box for scaling. Use includeLabels: false so only lines/vertices define bounds; labels do not affect scale (they are drawn separately within bounds).
    private func computeContentBox(includeLabels: Bool = true) {
        var xs: [Double] = []
        var ys: [Double] = []
        
        if let lineData = graphicData["lines"] as? [[String: Any]] {
            for line in lineData {
                if let x1 = Self._double(line["x1"]), let y1 = Self._double(line["y1"]),
                   let x2 = Self._double(line["x2"]), let y2 = Self._double(line["y2"]) {
                    xs.append(contentsOf: [x1, x2])
                    ys.append(contentsOf: [y1, y2])
                }
            }
        }
        if let vertexData = graphicData["vertices"] as? [[String: Any]] {
            for vertex in vertexData {
                if let x = Self._double(vertex["x"]), let y = Self._double(vertex["y"]) {
                    xs.append(x)
                    ys.append(y)
                }
            }
        }
        if includeLabels, let labelData = graphicData["labels"] as? [[String: Any]] {
            for label in labelData {
                if let x = Self._double(label["x"]), let y = Self._double(label["y"]) {
                    xs.append(x)
                    ys.append(y)
                }
            }
        }
        
        if xs.isEmpty || ys.isEmpty {
            contentBox = (viewBox.x, viewBox.y, viewBox.width, viewBox.height)
            return
        }
        
        let minX = xs.min()!, maxX = xs.max()!
        let minY = ys.min()!, maxY = ys.max()!
        let w = maxX - minX, h = maxY - minY
        let marginPct = 0.04
        let margin = max(marginPct * max(w, h), 1)
        
        contentBox = (
            minX - margin,
            minY - margin,
            (maxX - minX) + 2 * margin,
            (maxY - minY) + 2 * margin
        )
    }
    
    private func parseAndCalculateElements(drawingRect: CGRect? = nil) {
        // Parse viewBox
        if let vb = graphicData["viewBox"] as? [String: Any],
           let x = Self._double(vb["x"]), let y = Self._double(vb["y"]),
           let width = Self._double(vb["width"]), let height = Self._double(vb["height"]) {
            viewBox = (x, y, width, height)
        }
        computeContentBox(includeLabels: false)
        
        var availableRect = drawingRect ?? bounds
        let screenBounds = UIScreen.main.bounds
        if availableRect.width < 200 || availableRect.height < 200 {
            availableRect = screenBounds
        }
        let availableWidth = max(availableRect.width, 100)
        let availableHeight = max(availableRect.height, 100)
        
        let effectivePadding: CGFloat = max(4, strokeWidth4mm / 2 + 2)
        let drawableWidth = availableWidth - (effectivePadding * 2)
        let drawableHeight = availableHeight - (effectivePadding * 2)
        
        guard contentBox.width > 0 && contentBox.height > 0, drawableWidth > 0, drawableHeight > 0 else { return }
        
        let scaleX = drawableWidth / contentBox.width
        let scaleY = drawableHeight / contentBox.height
        let scale = min(scaleX, scaleY)
        
        let scaledWidth = contentBox.width * scale
        let scaledHeight = contentBox.height * scale
        let offsetX = effectivePadding + (drawableWidth - scaledWidth) / 2
        let offsetY = effectivePadding + (drawableHeight - scaledHeight) / 2
        
        lines.removeAll()
        if let lineData = graphicData["lines"] as? [[String: Any]] {
            for line in lineData {
                guard let x1 = Self._double(line["x1"]), let y1 = Self._double(line["y1"]),
                      let x2 = Self._double(line["x2"]), let y2 = Self._double(line["y2"]) else { continue }
                
                let start = CGPoint(
                    x: offsetX + CGFloat((x1 - contentBox.minX) * scale),
                    y: offsetY + CGFloat((y1 - contentBox.minY) * scale)
                )
                let end = CGPoint(
                    x: offsetX + CGFloat((x2 - contentBox.minX) * scale),
                    y: offsetY + CGFloat((y2 - contentBox.minY) * scale)
                )
                let label = line["label"] as? String
                lines.append((start: start, end: end, label: label))
            }
        }
        
        vertices.removeAll()
        if let vertexData = graphicData["vertices"] as? [[String: Any]] {
            for vertex in vertexData {
                guard let x = Self._double(vertex["x"]), let y = Self._double(vertex["y"]) else { continue }
                
                let point = CGPoint(
                    x: offsetX + CGFloat((x - contentBox.minX) * scale),
                    y: offsetY + CGFloat((y - contentBox.minY) * scale)
                )
                vertices.append(point)
            }
        }
        
        dimensionDots.removeAll()
        for (index, line) in lines.enumerated() {
            guard let label = line.label, !label.isEmpty else { continue }
            let t: CGFloat = 0.55
            let px = line.start.x + (line.end.x - line.start.x) * t
            let py = line.start.y + (line.end.y - line.start.y) * t
            dimensionDots.append(DimensionDot(point: CGPoint(x: px, y: py), lineIndex: index, label: label))
        }
    }
    
    // MARK: - Touch Handling
    
    private func handleTouchAt(_ point: CGPoint) {
        let onVertex = findVertexAt(point) != nil
        if let dotIndex = findDimensionDotAt(point), !onVertex {
            let justEnteredDot = activeDimensionDotIndex != dotIndex
            if justEnteredDot {
                cancelDimensionAnnouncement()
                lastAnnouncedLineIndex = dimensionDots[dotIndex].lineIndex
                UIAccessibility.post(notification: .announcement, argument: dimensionDots[dotIndex].label)
            }
            activeDimensionDotIndex = dotIndex
        } else {
            activeDimensionDotIndex = nil
        }
        
        if let lineIndex = findLineAt(point) {
            if activeLineIndex != lineIndex {
                stopContinuousHaptic()
                activeLineIndex = lineIndex
                startContinuousHaptic()
            }
            if let vertexIndex = findVertexAt(point) {
                if lastVertexIndex != vertexIndex {
                    lastVertexIndex = vertexIndex
                    playVertexDing()
                }
            } else {
                lastVertexIndex = nil
            }
        }
        // 3) Vertex only (not on a line)
        else if let vertexIndex = findVertexAt(point) {
            if activeLineIndex != nil {
                stopContinuousHaptic()
                activeLineIndex = nil
            }
            if lastVertexIndex != vertexIndex {
                lastVertexIndex = vertexIndex
                playVertexDing()
            }
        }
        // 4) Not on any element — stop feedback
        else {
            if activeLineIndex != nil {
                stopContinuousHaptic()
                activeLineIndex = nil
            }
            lastVertexIndex = nil
            cancelDimensionAnnouncement()
        }
    }
    
    // MARK: - Element Detection
    
    private func findDimensionDotAt(_ point: CGPoint) -> Int? {
        let touchRadius = max(dimensionDotRadius * 1.2, 18)
        for (index, dot) in dimensionDots.enumerated() {
            if hypot(point.x - dot.point.x, point.y - dot.point.y) < touchRadius {
                return index
            }
        }
        return nil
    }
    
    private func findVertexAt(_ point: CGPoint) -> Int? {
        let touchRadius = max(vertexDotRadius * 1.2, 18)
        for (index, vertex) in vertices.enumerated() {
            let distance = hypot(point.x - vertex.x, point.y - vertex.y)
            if distance < touchRadius {
                return index
            }
        }
        return nil
    }
    
    private func findLineAt(_ point: CGPoint) -> Int? {
        let touchRadius = max(strokeWidth4mm * 0.55, 10)
        
        var closestLineIndex: Int? = nil
        var closestDistance: CGFloat = touchRadius
        
        for (index, line) in lines.enumerated() {
            let distance = distanceFromPoint(point, toLineFrom: line.start, to: line.end)
            if distance < closestDistance {
                closestDistance = distance
                closestLineIndex = index
            }
        }
        
        return closestLineIndex
    }
    
    private func distanceFromPoint(_ point: CGPoint, toLineFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let lineLength = hypot(end.x - start.x, end.y - start.y)
        if lineLength == 0 {
            return hypot(point.x - start.x, point.y - start.y)
        }
        
        let t = max(0, min(1, ((point.x - start.x) * (end.x - start.x) +
                              (point.y - start.y) * (end.y - start.y)) /
                              (lineLength * lineLength)))
        
        let projectionX = start.x + t * (end.x - start.x)
        let projectionY = start.y + t * (end.y - start.y)
        
        return hypot(point.x - projectionX, point.y - projectionY)
    }
    
    // MARK: - Core Haptics (Works with VoiceOver)
    
    private func startContinuousHaptic() {
        // Always ensure engine is running first
        ensureHapticEngineRunning()
        
        guard let engine = hapticEngine else {
            startUIKitHaptic()
            return
        }
        
        do {
            // Stop any existing player
            try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
            continuousPlayer = nil
            
            // Create continuous haptic pattern
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [intensity, sharpness],
                relativeTime: 0,
                duration: 100
            )
            
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
            try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
            
        } catch {
            print("Core Haptics error: \(error)")
            startUIKitHaptic()
        }
    }
    
    private func stopContinuousHaptic() {
        // Stop Core Haptics
        if let player = continuousPlayer {
            do {
                try player.stop(atTime: CHHapticTimeImmediate)
            } catch {
                // Ignore errors when stopping
            }
            continuousPlayer = nil
        }
        
        // Stop UIKit fallback
        continuousHapticTimer?.invalidate()
        continuousHapticTimer = nil
    }
    
    // Fallback for devices without Core Haptics or when Core Haptics fails
    private func startUIKitHaptic() {
        stopContinuousHaptic()
        
        continuousHapticTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            guard let self = self, self.activeLineIndex != nil else { return }
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            gen.impactOccurred(intensity: 0.6)
        }
        
        if let timer = continuousHapticTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
        
        // Trigger first haptic immediately
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred()
    }
    
    // MARK: - Dimension Announcement (with pause)
    
    private func scheduleDimensionAnnouncement(lineIndex: Int) {
        // Cancel any pending announcement
        cancelDimensionAnnouncement()
        
        // Don't re-announce same line
        guard lineIndex != lastAnnouncedLineIndex else { return }
        
        // Schedule announcement after 0.5 second pause
        dimensionAnnounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.announceLineDimension(lineIndex: lineIndex)
        }
    }
    
    private func cancelDimensionAnnouncement() {
        dimensionAnnounceTimer?.invalidate()
        dimensionAnnounceTimer = nil
    }
    
    private func announceLineDimension(lineIndex: Int) {
        guard lineIndex < lines.count else { return }
        let line = lines[lineIndex]
        
        // Only announce if there's a dimension label
        if let label = line.label, !label.isEmpty {
            lastAnnouncedLineIndex = lineIndex
            UIAccessibility.post(notification: .announcement, argument: label)
        }
    }
    
    // MARK: - Vertex Ding Sound
    
    private func playVertexDing() {
        // Play system ding sound
        AudioServicesPlaySystemSound(1057)
        
        // Strong haptic pulse for vertex
        ensureHapticEngineRunning()
        
        if let engine = hapticEngine {
            do {
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                
                let event = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [intensity, sharpness],
                    relativeTime: 0
                )
                
                let pattern = try CHHapticPattern(events: [event], parameters: [])
                let player = try engine.makePlayer(with: pattern)
                try player.start(atTime: CHHapticTimeImmediate)
                
            } catch {
                // Fallback to UIKit
                playUIKitVertexHaptic()
            }
        } else {
            playUIKitVertexHaptic()
        }
    }
    
    private func playUIKitVertexHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred(intensity: 1.0)
    }
    
    // MARK: - Cleanup
    
    private func stopAllFeedback() {
        stopContinuousHaptic()
        cancelDimensionAnnouncement()
        activeLineIndex = nil
        lastVertexIndex = nil
        lastAnnouncedLineIndex = nil
        activeDimensionDotIndex = nil
    }
    
    deinit {
        stopAllFeedback()
        hapticEngine?.stop()
    }
}