//
//  MultisensorySVGView.swift
//  Education
//
//  Created for blind and low-vision users to explore graphics through touch and haptics
//
//  Touch feedback:
//  - Lines/edges: continuous vibration while tracing
//  - Vertices/corners: pulsing haptic + looping ding sound (loops while touching)
//  - Labels: red square touch targets positioned OUTSIDE figure, pulsing haptic + speech
//  - Three-finger swipe to go back
//

import SwiftUI
import UIKit
import AVFoundation
import AudioToolbox
import CoreHaptics

/// Multisensory view: figure only. User touches and feels the shape.
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .accessibilityAction(.escape) {
            dismiss()
        }
        .onAppear {
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

// Line width: 4 mm using device-specific PPI
private var strokeWidth4mm: CGFloat {
    PhysicalDimensions.mmToPoints(4.0)
}

// MARK: - JSON validation

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
            print("⚠️ [graphicData] Measurement label \"\(text)\" has forLine=\"\(forLineId)\", but that line has no label.")
        }
    }
    
    if let summary = figureSummary, (summary.lowercased().contains("base") && summary.lowercased().contains("height") && summary.lowercased().contains("label")) {
        let labeledCount = lineData.filter { line in
            guard let l = line["label"] as? String else { return false }
            return !l.isEmpty
        }.count
        if labeledCount < 2 {
            print("⚠️ [graphicData] Summary says base and height are labeled, but only \(labeledCount) line(s) have non-empty label.")
        }
    }
}

/// Touch target for a label: a square area that pulses and speaks
struct LabelTouchTarget {
    let center: CGPoint
    let text: String
    let halfSize: CGFloat
}

// MARK: - Canvas View

class MultisensoryCanvasView: UIView {
    var graphicData: [String: Any] = [:]
    var haptics: HapticService?
    var speech: SpeechService?
    var onDismiss: (() -> Void)?
    
    private var lines: [(start: CGPoint, end: CGPoint, label: String?)] = []
    private var vertices: [CGPoint] = []
    private var labelTargets: [LabelTouchTarget] = []
    private var viewBox: (x: Double, y: Double, width: Double, height: Double) = (0, 0, 448, 380)
    private var contentBox: (minX: Double, minY: Double, width: Double, height: Double) = (0, 0, 1, 1)
    
    // Active touch state
    private var activeLineIndex: Int? = nil
    private var activeVertexIndex: Int? = nil
    private var activeLabelIndex: Int? = nil
    
    // Haptic timers
    private var continuousHapticTimer: Timer?
    private var vertexDingTimer: Timer?
    private var vertexPulseTimer: Timer?
    private var labelPulseTimer: Timer?
    
    // Core Haptics
    private var hapticEngine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    
    // Announcement dedup
    private var lastAnnouncedLabelIndex: Int? = nil
    
    // Sizing
    private var vertexDotRadius: CGFloat { max(PhysicalDimensions.mmToPoints(6.0) / 2, 10) }
    private var labelSquareHalfSize: CGFloat { max(PhysicalDimensions.mmToPoints(6.0) / 2, 14) }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        isAccessibilityElement = true
        accessibilityTraits = [.allowsDirectInteraction]
        accessibilityLabel = "Tactile figure. Explore by touch."
        setupHapticEngine()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }
    
    // MARK: - Core Haptics Setup
    
    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.isAutoShutdownEnabled = false
            hapticEngine?.playsHapticsOnly = true
            
            hapticEngine?.resetHandler = { [weak self] in
                do { try self?.hapticEngine?.start() } catch { }
            }
            hapticEngine?.stoppedHandler = { [weak self] _ in
                do { try self?.hapticEngine?.start() } catch { }
            }
            
            try hapticEngine?.start()
        } catch {
            print("Failed to create haptic engine: \(error)")
        }
    }
    
    private func ensureHapticEngineRunning() {
        guard let engine = hapticEngine else { return }
        do { try engine.start() } catch { }
    }
    
    // MARK: - Gestures
    
    func setupGestures() {
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
        
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
    
    // MARK: - Touch Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        ensureHapticEngineRunning()
        let point = touch.location(in: self)
        logGraphicTouch(event: .touchDown, at: point)
        handleTouchAt(point)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        logGraphicTouch(event: .touchMove, at: point)
        handleTouchAt(point)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let point = touch.location(in: self)
            logGraphicTouch(event: .touchUp, at: point)
        }
        stopAllFeedback()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let point = touch.location(in: self)
            logGraphicTouch(event: .touchUp, at: point)
        }
        stopAllFeedback()
    }
    
    private func handleTouchAt(_ point: CGPoint) {
        // Priority 1: Vertex (corner/intersection) — pulsing + looping ding
        if let vIdx = findVertexAt(point) {
            if activeVertexIndex != vIdx {
                stopLineFeedback()
                stopLabelFeedback()
                activeVertexIndex = vIdx
                startVertexFeedback()
            }
            activeLineIndex = nil
            activeLabelIndex = nil
            return
        } else if activeVertexIndex != nil {
            stopVertexFeedback()
            activeVertexIndex = nil
        }
        
        // Priority 2: Label square — pulsing + speech
        if let lIdx = findLabelAt(point) {
            if activeLabelIndex != lIdx {
                stopLineFeedback()
                stopVertexFeedback()
                activeLabelIndex = lIdx
                startLabelFeedback(index: lIdx)
            }
            activeLineIndex = nil
            activeVertexIndex = nil
            return
        } else if activeLabelIndex != nil {
            stopLabelFeedback()
            activeLabelIndex = nil
            lastAnnouncedLabelIndex = nil
        }
        
        // Priority 3: Line (edge) — continuous vibration
        if let lineIdx = findLineAt(point) {
            if activeLineIndex != lineIdx {
                stopVertexFeedback()
                stopLabelFeedback()
                activeLineIndex = lineIdx
                startLineContinuousHaptic()
            }
        } else {
            if activeLineIndex != nil {
                stopLineFeedback()
                activeLineIndex = nil
            }
        }
    }
    
    /// Log what the user is currently touching in the multisensory graphic.
    private func logGraphicTouch(event: TouchEventType, at point: CGPoint) {
        let (objectType, label) = classifyGraphicElement(at: point)
        InteractionLogger.shared.log(
            event: event,
            objectType: objectType,
            label: label,
            location: point,
            additionalInfo: "Multisensory SVG"
        )
    }
    
    /// Classify the current touch point as vertex / label / line / background for logging.
    private func classifyGraphicElement(at point: CGPoint) -> (ObjectType, String) {
        if let vIdx = findVertexAt(point) {
            return (.svg, "Vertex \(vIdx + 1)")
        }
        
        if let lIdx = findLabelAt(point), lIdx < labelTargets.count {
            let text = labelTargets[lIdx].text
            return (.svg, "Label: \(text)")
        }
        
        if let lineIdx = findLineAt(point), lineIdx < lines.count {
            let lineLabel = lines[lineIdx].label ?? "Line \(lineIdx + 1)"
            return (.svg, lineLabel)
        }
        
        return (.svg, "Background")
    }
    
    // MARK: - Element Detection
    
    private func findVertexAt(_ point: CGPoint) -> Int? {
        let touchRadius = max(vertexDotRadius * 1.3, 20)
        for (index, vertex) in vertices.enumerated() {
            if hypot(point.x - vertex.x, point.y - vertex.y) < touchRadius {
                return index
            }
        }
        return nil
    }
    
    private func findLabelAt(_ point: CGPoint) -> Int? {
        for (index, target) in labelTargets.enumerated() {
            let dx = abs(point.x - target.center.x)
            let dy = abs(point.y - target.center.y)
            if dx < target.halfSize + 10 && dy < target.halfSize + 10 {
                return index
            }
        }
        return nil
    }
    
    private func findLineAt(_ point: CGPoint) -> Int? {
        let touchRadius = max(strokeWidth4mm * 0.55, 10)
        var closestIdx: Int? = nil
        var closestDist: CGFloat = touchRadius
        
        for (index, line) in lines.enumerated() {
            let d = distanceFromPoint(point, toLineFrom: line.start, to: line.end)
            if d < closestDist {
                closestDist = d
                closestIdx = index
            }
        }
        return closestIdx
    }
    
    private func distanceFromPoint(_ point: CGPoint, toLineFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let lineLength = hypot(end.x - start.x, end.y - start.y)
        if lineLength == 0 { return hypot(point.x - start.x, point.y - start.y) }
        let t = max(0, min(1, ((point.x - start.x) * (end.x - start.x) + (point.y - start.y) * (end.y - start.y)) / (lineLength * lineLength)))
        let px = start.x + t * (end.x - start.x)
        let py = start.y + t * (end.y - start.y)
        return hypot(point.x - px, point.y - py)
    }
    
    // MARK: - LINE Feedback (continuous vibration)
    
    private func startLineContinuousHaptic() {
        ensureHapticEngineRunning()
        guard let engine = hapticEngine else { startUIKitLineFallback(); return }
        
        do {
            try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
            continuousPlayer = nil
            
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 100)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
            try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {
            startUIKitLineFallback()
        }
    }
    
    private func startUIKitLineFallback() {
        continuousHapticTimer?.invalidate()
        continuousHapticTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            guard self?.activeLineIndex != nil else { return }
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            gen.impactOccurred(intensity: 0.6)
        }
        if let t = continuousHapticTimer { RunLoop.current.add(t, forMode: .common) }
    }
    
    private func stopLineFeedback() {
        if let p = continuousPlayer { do { try p.stop(atTime: CHHapticTimeImmediate) } catch { } }
        continuousPlayer = nil
        continuousHapticTimer?.invalidate()
        continuousHapticTimer = nil
    }
    
    // MARK: - VERTEX Feedback (pulsing haptic + looping ding)
    
    private func startVertexFeedback() {
        // Start pulsing haptic
        startVertexPulsingHaptic()
        // Play ding immediately
        playVertexDing()
        // Start looping ding every 0.4s
        vertexDingTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            guard self?.activeVertexIndex != nil else { return }
            self?.playVertexDing()
        }
        if let t = vertexDingTimer { RunLoop.current.add(t, forMode: .common) }
    }
    
    private func startVertexPulsingHaptic() {
        ensureHapticEngineRunning()
        guard let engine = hapticEngine else { startUIKitVertexPulseFallback(); return }
        
        do {
            var events: [CHHapticEvent] = []
            for i in 0..<250 {
                let time = Double(i) * 0.15  // pulse every 150ms
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: time))
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            continuousPlayer = player
        } catch {
            startUIKitVertexPulseFallback()
        }
    }
    
    private func startUIKitVertexPulseFallback() {
        vertexPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard self?.activeVertexIndex != nil else { return }
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.prepare()
            gen.impactOccurred(intensity: 1.0)
        }
        if let t = vertexPulseTimer { RunLoop.current.add(t, forMode: .common) }
    }
    
    private func stopVertexFeedback() {
        if let p = continuousPlayer { do { try p.stop(atTime: CHHapticTimeImmediate) } catch { } }
        continuousPlayer = nil
        vertexPulseTimer?.invalidate()
        vertexPulseTimer = nil
        vertexDingTimer?.invalidate()
        vertexDingTimer = nil
    }
    
    private func playVertexDing() {
        AudioServicesPlaySystemSound(1057)
    }
    
    // MARK: - LABEL Feedback (pulsing haptic + speak)
    
    private func startLabelFeedback(index: Int) {
        // Announce text
        if lastAnnouncedLabelIndex != index {
            lastAnnouncedLabelIndex = index
            let text = labelTargets[index].text
            UIAccessibility.post(notification: .announcement, argument: text)
        }
        // Pulsing haptic
        startLabelPulsingHaptic()
    }
    
    private func startLabelPulsingHaptic() {
        ensureHapticEngineRunning()
        guard let engine = hapticEngine else { startUIKitLabelPulseFallback(); return }
        
        do {
            var events: [CHHapticEvent] = []
            for i in 0..<200 {
                let time = Double(i) * 0.2  // pulse every 200ms
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: time))
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            continuousPlayer = player
        } catch {
            startUIKitLabelPulseFallback()
        }
    }
    
    private func startUIKitLabelPulseFallback() {
        labelPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard self?.activeLabelIndex != nil else { return }
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            gen.impactOccurred(intensity: 0.8)
        }
        if let t = labelPulseTimer { RunLoop.current.add(t, forMode: .common) }
    }
    
    private func stopLabelFeedback() {
        if let p = continuousPlayer { do { try p.stop(atTime: CHHapticTimeImmediate) } catch { } }
        continuousPlayer = nil
        labelPulseTimer?.invalidate()
        labelPulseTimer = nil
    }
    
    // MARK: - Cleanup
    
    private func stopAllFeedback() {
        stopLineFeedback()
        stopVertexFeedback()
        stopLabelFeedback()
        activeLineIndex = nil
        activeVertexIndex = nil
        activeLabelIndex = nil
        lastAnnouncedLabelIndex = nil
    }
    
    deinit {
        stopAllFeedback()
        hapticEngine?.stop()
    }
    
    // MARK: - Drawing
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        parseAndCalculateElements(drawingRect: rect)
        
        // 1. Draw lines (black, 4mm stroke)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setLineWidth(strokeWidth4mm)
        
        for line in lines {
            context.move(to: line.start)
            context.addLine(to: line.end)
            context.strokePath()
        }
        
        // 2. Draw vertex dots (red circles)
        context.setFillColor(UIColor.systemRed.cgColor)
        for vertex in vertices {
            let r = vertexDotRadius
            context.fillEllipse(in: CGRect(x: vertex.x - r, y: vertex.y - r, width: r * 2, height: r * 2))
        }
        
        // 3. Draw label touch targets (RED squares on line) + text AWAY from line
        for (index, target) in labelTargets.enumerated() {
            let s = labelSquareHalfSize
            let squareRect = CGRect(x: target.center.x - s, y: target.center.y - s, width: s * 2, height: s * 2)
            
            // Solid red square ON the line
            context.setFillColor(UIColor.systemRed.cgColor)
            context.fill(squareRect)
            
            // Find the line direction to compute perpendicular offset for text
            let textOffset: CGFloat = 30
            var textCenter = CGPoint(x: target.center.x, y: target.center.y + textOffset) // default: below
            
            // Find which line this label belongs to
            if index < lines.count || true {
                // Find the closest line to this label's center
                var bestLine: (start: CGPoint, end: CGPoint, label: String?)? = nil
                var bestDist: CGFloat = .greatestFiniteMagnitude
                for line in lines {
                    let mid = CGPoint(x: (line.start.x + line.end.x) / 2, y: (line.start.y + line.end.y) / 2)
                    let d = hypot(mid.x - target.center.x, mid.y - target.center.y)
                    if d < bestDist { bestDist = d; bestLine = line }
                }
                
                if let line = bestLine {
                    // Perpendicular to the line
                    let dx = line.end.x - line.start.x
                    let dy = line.end.y - line.start.y
                    let len = hypot(dx, dy)
                    if len > 0 {
                        // Normal direction (perpendicular)
                        let nx = -dy / len
                        let ny = dx / len
                        
                        // Pick direction away from figure center
                        let figCenterX = vertices.isEmpty ? bounds.midX : vertices.reduce(0.0) { $0 + $1.x } / CGFloat(vertices.count)
                        let figCenterY = vertices.isEmpty ? bounds.midY : vertices.reduce(0.0) { $0 + $1.y } / CGFloat(vertices.count)
                        
                        let c1 = CGPoint(x: target.center.x + nx * textOffset, y: target.center.y + ny * textOffset)
                        let c2 = CGPoint(x: target.center.x - nx * textOffset, y: target.center.y - ny * textOffset)
                        
                        let d1 = hypot(c1.x - figCenterX, c1.y - figCenterY)
                        let d2 = hypot(c2.x - figCenterX, c2.y - figCenterY)
                        
                        textCenter = d1 >= d2 ? c1 : c2
                    }
                }
            }
            
            // Draw text at offset position
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 15),
                .foregroundColor: UIColor.black
            ]
            let textSize = (target.text as NSString).size(withAttributes: attributes)
            
            var textX = textCenter.x - textSize.width / 2
            var textY = textCenter.y - textSize.height / 2
            
            // Clamp to screen bounds
            textX = max(4, min(bounds.width - textSize.width - 4, textX))
            textY = max(4, min(bounds.height - textSize.height - 4, textY))
            
            // White background
            let bgRect = CGRect(x: textX - 3, y: textY - 2, width: textSize.width + 6, height: textSize.height + 4)
            context.setFillColor(UIColor.white.cgColor)
            context.fill(bgRect)
            
            (target.text as NSString).draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
        }
    }
    
    // MARK: - Parsing
    
    private static func _double(_ value: Any?) -> Double? {
        guard let v = value else { return nil }
        if let n = v as? NSNumber { return n.doubleValue }
        if let d = v as? Double { return d }
        return nil
    }
    
    private func computeContentBox() {
        var xs: [Double] = []
        var ys: [Double] = []
        
        if let lineData = graphicData["lines"] as? [[String: Any]] {
            for line in lineData {
                if let x1 = Self._double(line["x1"]), let y1 = Self._double(line["y1"]),
                   let x2 = Self._double(line["x2"]), let y2 = Self._double(line["y2"]) {
                    xs.append(contentsOf: [x1, x2]); ys.append(contentsOf: [y1, y2])
                }
            }
        }
        if let vertexData = graphicData["vertices"] as? [[String: Any]] {
            for v in vertexData {
                if let x = Self._double(v["x"]), let y = Self._double(v["y"]) { xs.append(x); ys.append(y) }
            }
        }
        
        if xs.isEmpty || ys.isEmpty {
            contentBox = (viewBox.x, viewBox.y, viewBox.width, viewBox.height)
            return
        }
        
        let minX = xs.min()!, maxX = xs.max()!, minY = ys.min()!, maxY = ys.max()!
        let w = maxX - minX, h = maxY - minY
        let margin = max(0.08 * max(w, h), 5)
        contentBox = (minX - margin, minY - margin, w + 2 * margin, h + 2 * margin)
    }
    
    private func parseAndCalculateElements(drawingRect: CGRect? = nil) {
        if let vb = graphicData["viewBox"] as? [String: Any],
           let x = Self._double(vb["x"]), let y = Self._double(vb["y"]),
           let width = Self._double(vb["width"]), let height = Self._double(vb["height"]) {
            viewBox = (x, y, width, height)
        }
        computeContentBox()
        
        var availableRect = drawingRect ?? bounds
        let screenBounds = UIScreen.main.bounds
        if availableRect.width < 200 || availableRect.height < 200 { availableRect = screenBounds }
        
        let pad: CGFloat = max(4, strokeWidth4mm / 2 + 2)
        let dw = max(availableRect.width, 100) - pad * 2
        let dh = max(availableRect.height, 100) - pad * 2
        guard contentBox.width > 0 && contentBox.height > 0, dw > 0, dh > 0 else { return }
        
        let scale = min(dw / contentBox.width, dh / contentBox.height)
        let sw = contentBox.width * scale, sh = contentBox.height * scale
        let ox = pad + (dw - sw) / 2, oy = pad + (dh - sh) / 2
        
        func mapPoint(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: ox + CGFloat((x - contentBox.minX) * scale),
                    y: oy + CGFloat((y - contentBox.minY) * scale))
        }
        
        // Parse lines
        lines.removeAll()
        if let lineData = graphicData["lines"] as? [[String: Any]] {
            for line in lineData {
                guard let x1 = Self._double(line["x1"]), let y1 = Self._double(line["y1"]),
                      let x2 = Self._double(line["x2"]), let y2 = Self._double(line["y2"]) else { continue }
                let label = line["label"] as? String
                lines.append((start: mapPoint(x1, y1), end: mapPoint(x2, y2), label: label))
            }
        }
        
        // Parse vertices
        vertices.removeAll()
        if let vertexData = graphicData["vertices"] as? [[String: Any]] {
            for v in vertexData {
                guard let x = Self._double(v["x"]), let y = Self._double(v["y"]) else { continue }
                vertices.append(mapPoint(x, y))
            }
        }
        
        // Parse labels → red square ON the line at midpoint
        labelTargets.removeAll()
        
        // From explicit graphicData["labels"]
        if let labelData = graphicData["labels"] as? [[String: Any]] {
            for label in labelData {
                guard let text = label["text"] as? String, !text.isEmpty else { continue }
                
                var center: CGPoint? = nil
                
                // Find the line this label belongs to and place square at midpoint
                if let forLineId = label["forLine"] as? String,
                   let lineArr = graphicData["lines"] as? [[String: Any]],
                   let matchLine = lineArr.first(where: { ($0["id"] as? String) == forLineId }) {
                    if let lx1 = Self._double(matchLine["x1"]), let ly1 = Self._double(matchLine["y1"]),
                       let lx2 = Self._double(matchLine["x2"]), let ly2 = Self._double(matchLine["y2"]) {
                        let p1 = mapPoint(lx1, ly1), p2 = mapPoint(lx2, ly2)
                        center = CGPoint(x: (p1.x + p2.x) / 2, y: (p1.y + p2.y) / 2)
                    }
                }
                
                // Fall back to label's own coordinates
                if center == nil, let lx = Self._double(label["x"]), let ly = Self._double(label["y"]) {
                    center = mapPoint(lx, ly)
                }
                
                guard let c = center else { continue }
                labelTargets.append(LabelTouchTarget(center: c, text: text, halfSize: labelSquareHalfSize))
            }
        }
        
        // Also from labeled lines not already covered — square at midpoint
        for line in lines {
            guard let lineLabel = line.label, !lineLabel.isEmpty else { continue }
            let alreadyHasTarget = labelTargets.contains { $0.text == lineLabel }
            if !alreadyHasTarget {
                let mid = CGPoint(x: (line.start.x + line.end.x) / 2, y: (line.start.y + line.end.y) / 2)
                labelTargets.append(LabelTouchTarget(center: mid, text: lineLabel, halfSize: labelSquareHalfSize))
            }
        }
    }
    
    // MARK: - VoiceOver 3-finger swipe
    
    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        if direction == .right || direction == .left {
            stopAllFeedback()
            onDismiss?()
            return true
        }
        return false
    }
    
    override func accessibilityPerformEscape() -> Bool {
        stopAllFeedback()
        onDismiss?()
        return true
    }
}
