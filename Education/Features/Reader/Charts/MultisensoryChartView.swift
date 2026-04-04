//
//  MultisensoryChartView.swift
//  Education
//
//  Full-screen tactile exploration for bar charts, pie charts, and line graphs.
//  Follows the same pattern as MultisensorySVGView:
//    - Lines/bars: continuous vibration while tracing
//    - Data points / vertices: pulsing haptic + looping ding
//    - Labels announced via VoiceOver
//    - Three-finger swipe or Back button to exit
//

import SwiftUI
import UIKit
import CoreHaptics
import AudioToolbox

// MARK: - Chart Type Enum

enum ChartKind {
    case bar(bars: [(label: String, value: Double, color: UIColor)], isVertical: Bool)
    case pie(slices: [(label: String, value: Double, color: UIColor)])
    case line(series: [(name: String, points: [(x: String, y: Double)], color: UIColor)])
}

// MARK: - SwiftUI Wrapper

struct MultisensoryChartView: View {
    let chartKind: ChartKind
    let title: String?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                MultisensoryChartRepresentable(
                    chartKind: chartKind,
                    onDismiss: { dismiss() }
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Back")
                                .font(.custom("Arial", size: 17))
                        }
                        .foregroundColor(ColorTokens.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityLabel("Back")
                    .accessibilityHint("Return to document")

                    Spacer()
                }
                .padding(.top, 56)
                .padding(.leading, 16)

                Spacer()
            }
        }
        .accessibilityAction(.escape) {
            dismiss()
        }
        .onAppear {
            let message = "Tactile chart. Touch and explore. Use 3 finger swipe or Back button to go back."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                UIAccessibility.post(notification: .announcement, argument: message)
            }
            InteractionLogger.shared.log(
                event: .screenTransition,
                objectType: .chart,
                label: title ?? "Multisensory Chart",
                location: .zero,
                additionalInfo: "Entered multisensory chart exploration"
            )
        }
    }
}

// MARK: - UIViewRepresentable

private struct MultisensoryChartRepresentable: UIViewRepresentable {
    let chartKind: ChartKind
    let onDismiss: () -> Void

    func makeUIView(context: Context) -> MultisensoryChartCanvas {
        let view = MultisensoryChartCanvas()
        view.chartKind = chartKind
        view.onDismiss = onDismiss
        view.setupGestures()
        return view
    }

    func updateUIView(_ uiView: MultisensoryChartCanvas, context: Context) {
        uiView.chartKind = chartKind
        uiView.setNeedsDisplay()
    }
}

// MARK: - Canvas View

class MultisensoryChartCanvas: UIView {
    var chartKind: ChartKind = .bar(bars: [], isVertical: true)
    var onDismiss: (() -> Void)?

    // Computed hit regions after drawing
    private var barRects: [(rect: CGRect, label: String, value: Double, color: UIColor)] = []
    private var pieSlices: [(startAngle: Double, endAngle: Double, label: String, value: Double, pct: Double, color: UIColor)] = []
    private var lineSegments: [(start: CGPoint, end: CGPoint)] = []
    private var dataPoints: [(center: CGPoint, label: String, value: Double)] = []

    // Active touch state
    private var activeBarIndex: Int?
    private var activeSliceIndex: Int?
    private var activePointIndex: Int?
    private var activeLineSegment: Bool = false
    private var lastAnnouncedIndex: Int?

    // Core Haptics
    private var hapticEngine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?

    // Fallback timers
    private var continuousHapticTimer: Timer?
    private var vertexDingTimer: Timer?
    private var vertexPulseTimer: Timer?

    // Tactile thickness hierarchy (BANA + Tactile Vega-Lite research):
    //   Line graph paths: 3mm — bold enough to trace, thin enough to see data shape
    //   Bar outlines: 1.5pt fixed — bars are identified by fill, not outline
    //   Pie separators: 2mm — boundary between slices
    //   Data points: 6mm diameter (BANA minimum 1/4 inch)
    private var dataLineWidth: CGFloat { PhysicalDimensions.mmToPoints(3.0) }
    private let barOutlineWidth: CGFloat = 1.5
    private var sliceSeparatorWidth: CGFloat { PhysicalDimensions.mmToPoints(2.0) }
    private var dataPointRadius: CGFloat { max(PhysicalDimensions.mmToPoints(3.0), 10) }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        isAccessibilityElement = true
        accessibilityTraits = [.allowsDirectInteraction]
        accessibilityLabel = "Tactile chart. Explore by touch."
        setupHapticEngine()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Core Haptics

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.isAutoShutdownEnabled = false
            hapticEngine?.playsHapticsOnly = true
            hapticEngine?.resetHandler = { [weak self] in
                do { try self?.hapticEngine?.start() } catch {}
            }
            hapticEngine?.stoppedHandler = { [weak self] _ in
                do { try self?.hapticEngine?.start() } catch {}
            }
            try hapticEngine?.start()
        } catch {}
    }

    private func ensureEngine() {
        guard let e = hapticEngine else { return }
        do { try e.start() } catch {}
    }

    // MARK: - Gestures

    func setupGestures() {
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
        for dir: UISwipeGestureRecognizer.Direction in [.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(threeFingerSwipe(_:)))
            swipe.direction = dir
            swipe.numberOfTouchesRequired = 3
            addGestureRecognizer(swipe)
        }
    }

    @objc private func threeFingerSwipe(_ g: UISwipeGestureRecognizer) {
        if g.state == .recognized { stopAll(); onDismiss?() }
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        ensureEngine()
        handleTouch(t.location(in: self))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        handleTouch(t.location(in: self))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { stopAll() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { stopAll() }

    private func handleTouch(_ pt: CGPoint) {
        switch chartKind {
        case .bar: handleBarTouch(pt)
        case .pie: handlePieTouch(pt)
        case .line: handleLineTouch(pt)
        }
    }

    // MARK: - Bar Touch

    private func handleBarTouch(_ pt: CGPoint) {
        for (i, bar) in barRects.enumerated() {
            if bar.rect.contains(pt) {
                // Top edge = data point
                let topEdge = CGRect(x: bar.rect.minX, y: bar.rect.minY - 8, width: bar.rect.width, height: 16)
                if topEdge.contains(pt) {
                    if activeBarIndex != i || !isVertexActive() {
                        stopAll()
                        activeBarIndex = i
                        startVertexFeedback()
                        announceIfNew(i, text: "\(bar.label): \(fmtVal(bar.value))")
                    }
                } else {
                    if activeBarIndex != i || isVertexActive() {
                        stopAll()
                        activeBarIndex = i
                        // Value-mapped intensity: higher bars vibrate stronger
                        let maxVal = barRects.map(\.value).max() ?? 1
                        let intensity = Float(0.3 + 0.7 * (bar.value / maxVal))
                        startContinuousHaptic(intensity: intensity)
                        announceIfNew(i, text: bar.label)
                    }
                }
                return
            }
        }
        if activeBarIndex != nil { stopAll() }
    }

    // MARK: - Pie Touch

    private func handlePieTouch(_ pt: CGPoint) {
        let cx = bounds.midX
        let cy = bounds.midY
        let radius = min(bounds.width, bounds.height) / 2 - 40
        let dx = pt.x - cx, dy = pt.y - cy
        let dist = hypot(dx, dy)
        guard dist <= radius else { if activeSliceIndex != nil { stopAll() }; return }

        var angle = atan2(dy, dx) * 180 / .pi + 90
        if angle < 0 { angle += 360 }

        // Check boundary between slices (within 8 degrees)
        for (i, slice) in pieSlices.enumerated() {
            let startDeg = slice.startAngle
            let endDeg = slice.endAngle
            let nearStart = abs(angle - startDeg) < 8 || abs(angle - startDeg + 360) < 8 || abs(angle - startDeg - 360) < 8
            let nearEnd = abs(angle - endDeg) < 8 || abs(angle - endDeg + 360) < 8 || abs(angle - endDeg - 360) < 8
            if nearStart || nearEnd {
                if !isVertexActive() {
                    stopAll()
                    activeSliceIndex = i
                    startVertexFeedback()
                }
                return
            }
        }

        // Inside a slice
        for (i, slice) in pieSlices.enumerated() {
            let inSlice: Bool
            if slice.startAngle < slice.endAngle {
                inSlice = angle >= slice.startAngle && angle < slice.endAngle
            } else {
                inSlice = angle >= slice.startAngle || angle < slice.endAngle
            }
            if inSlice {
                if activeSliceIndex != i || isVertexActive() {
                    stopAll()
                    activeSliceIndex = i
                    // Pie slices: crisper haptic (sharpness 0.7) with pct-mapped intensity
                    let maxPct = pieSlices.map(\.pct).max() ?? 1
                    let pctIntensity = Float(0.3 + 0.7 * (slice.pct / maxPct))
                    startContinuousHaptic(intensity: pctIntensity, sharpnessValue: 0.7)
                    announceIfNew(i, text: "\(slice.label): \(String(format: "%.0f", slice.pct)) percent")
                }
                return
            }
        }
    }

    // MARK: - Line Touch

    private func handleLineTouch(_ pt: CGPoint) {
        // Priority 1: data point
        for (i, dp) in dataPoints.enumerated() {
            if hypot(pt.x - dp.center.x, pt.y - dp.center.y) < dataPointRadius * 1.5 {
                if activePointIndex != i || !isVertexActive() {
                    stopAll()
                    activePointIndex = i
                    startVertexFeedback()
                    announceIfNew(i, text: "\(dp.label): \(fmtVal(dp.value))")
                }
                return
            }
        }

        // Priority 2: line segment
        let threshold: CGFloat = 16
        for seg in lineSegments {
            if distToSegment(pt, seg.start, seg.end) < threshold {
                if !activeLineSegment {
                    stopAll()
                    activeLineSegment = true
                    // Line segments: smoother wave-like haptic (sharpness 0.2)
                    startContinuousHaptic(intensity: 0.6, sharpnessValue: 0.2)
                }
                return
            }
        }

        if activePointIndex != nil || activeLineSegment { stopAll() }
    }

    private func distToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let l2 = pow(b.x - a.x, 2) + pow(b.y - a.y, 2)
        if l2 == 0 { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * (b.x - a.x) + (p.y - a.y) * (b.y - a.y)) / l2))
        let px = a.x + t * (b.x - a.x), py = a.y + t * (b.y - a.y)
        return hypot(p.x - px, p.y - py)
    }

    // MARK: - Announcements

    private func announceIfNew(_ index: Int, text: String) {
        guard lastAnnouncedIndex != index else { return }
        lastAnnouncedIndex = index
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    private func isVertexActive() -> Bool {
        vertexDingTimer != nil
    }

    // MARK: - Continuous Haptic (line/bar/slice body)

    private func startContinuousHaptic(intensity intensityValue: Float = 0.7, sharpnessValue: Float = 0.5) {
        ensureEngine()
        guard let engine = hapticEngine else { startUIKitContinuousFallback(); return }
        do {
            try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
            continuousPlayer = nil
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityValue)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpnessValue)
            let event = CHHapticEvent(eventType: .hapticContinuous, parameters: [intensity, sharpness], relativeTime: 0, duration: 100)
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            continuousPlayer = try engine.makeAdvancedPlayer(with: pattern)
            try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
        } catch { startUIKitContinuousFallback() }
    }

    private func startUIKitContinuousFallback() {
        continuousHapticTimer?.invalidate()
        continuousHapticTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { _ in
            let g = UIImpactFeedbackGenerator(style: .medium)
            g.prepare(); g.impactOccurred(intensity: 0.6)
        }
        if let t = continuousHapticTimer { RunLoop.current.add(t, forMode: .common) }
    }

    private func stopContinuous() {
        if let p = continuousPlayer { do { try p.stop(atTime: CHHapticTimeImmediate) } catch {} }
        continuousPlayer = nil
        continuousHapticTimer?.invalidate()
        continuousHapticTimer = nil
    }

    // MARK: - Vertex Haptic (data point / bar top / slice boundary)

    private func startVertexFeedback() {
        startVertexPulse()
        AudioServicesPlaySystemSound(1057)
        vertexDingTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            AudioServicesPlaySystemSound(1057)
        }
        if let t = vertexDingTimer { RunLoop.current.add(t, forMode: .common) }
    }

    private func startVertexPulse() {
        ensureEngine()
        guard let engine = hapticEngine else { startUIKitVertexFallback(); return }
        do {
            var events: [CHHapticEvent] = []
            for i in 0..<250 {
                let time = Double(i) * 0.15
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: time))
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
            continuousPlayer = player
        } catch { startUIKitVertexFallback() }
    }

    private func startUIKitVertexFallback() {
        vertexPulseTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { _ in
            let g = UIImpactFeedbackGenerator(style: .heavy)
            g.prepare(); g.impactOccurred(intensity: 1.0)
        }
        if let t = vertexPulseTimer { RunLoop.current.add(t, forMode: .common) }
    }

    private func stopVertex() {
        if let p = continuousPlayer { do { try p.stop(atTime: CHHapticTimeImmediate) } catch {} }
        continuousPlayer = nil
        vertexPulseTimer?.invalidate(); vertexPulseTimer = nil
        vertexDingTimer?.invalidate(); vertexDingTimer = nil
    }

    private func stopAll() {
        stopContinuous()
        stopVertex()
        activeBarIndex = nil
        activeSliceIndex = nil
        activePointIndex = nil
        activeLineSegment = false
        lastAnnouncedIndex = nil
    }

    deinit { stopAll(); hapticEngine?.stop() }

    // MARK: - VoiceOver escape

    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        if direction == .right || direction == .left { stopAll(); onDismiss?(); return true }
        return false
    }

    override func accessibilityPerformEscape() -> Bool { stopAll(); onDismiss?(); return true }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        // Leave room for Back button (top ~56pt + ~44pt button = ~100pt) + extra breathing room
        let topPad: CGFloat = 120
        let sidePad: CGFloat = 40
        let bottomPad: CGFloat = 60
        let drawRect = CGRect(
            x: rect.minX + sidePad,
            y: rect.minY + topPad,
            width: rect.width - sidePad * 2,
            height: rect.height - topPad - bottomPad
        )

        switch chartKind {
        case .bar(let bars, let isVertical):
            drawBarChart(ctx: ctx, bars: bars, isVertical: isVertical, in: drawRect)
        case .pie(let slices):
            drawPieChart(ctx: ctx, slices: slices, in: drawRect)
        case .line(let series):
            drawLineChart(ctx: ctx, series: series, in: drawRect)
        }
    }

    // MARK: - Draw Bar Chart

    private func drawBarChart(ctx: CGContext, bars: [(label: String, value: Double, color: UIColor)], isVertical: Bool, in area: CGRect) {
        barRects.removeAll()
        guard !bars.isEmpty else { return }
        let maxVal = bars.map(\.value).max() ?? 1

        let labelAreaHeight: CGFloat = 24   // space for category labels at bottom
        let valueAreaHeight: CGFloat = 20   // space for value labels on top
        let chartArea = CGRect(
            x: area.minX,
            y: area.minY + valueAreaHeight,
            width: area.width,
            height: area.height - labelAreaHeight - valueAreaHeight
        )

        if isVertical {
            let gap: CGFloat = max(8, area.width * 0.03)
            let barWidth = (chartArea.width - gap * CGFloat(bars.count + 1)) / CGFloat(bars.count)
            for (i, bar) in bars.enumerated() {
                let x = chartArea.minX + gap + CGFloat(i) * (barWidth + gap)
                let h = CGFloat(bar.value / maxVal) * chartArea.height
                let y = chartArea.maxY - h
                let r = CGRect(x: x, y: y, width: barWidth, height: h)

                ctx.setFillColor(bar.color.cgColor)
                ctx.fill(r)
                ctx.setStrokeColor(UIColor.black.cgColor)
                ctx.setLineWidth(barOutlineWidth)
                ctx.stroke(r)

                barRects.append((rect: r, label: bar.label, value: bar.value, color: bar.color))

                // Label below
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 13),
                    .foregroundColor: UIColor.black
                ]
                let size = (bar.label as NSString).size(withAttributes: attrs)
                let lx = x + (barWidth - size.width) / 2
                (bar.label as NSString).draw(at: CGPoint(x: max(chartArea.minX, lx), y: chartArea.maxY + 4), withAttributes: attrs)

                // Value on top
                let valStr = fmtVal(bar.value)
                let valAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 12),
                    .foregroundColor: UIColor.darkGray
                ]
                let vs = (valStr as NSString).size(withAttributes: valAttrs)
                (valStr as NSString).draw(at: CGPoint(x: x + (barWidth - vs.width) / 2, y: y - 18), withAttributes: valAttrs)
            }
        } else {
            let gap: CGFloat = 8
            let labelWidth: CGFloat = 90
            let barH = min(44, (chartArea.height - gap * CGFloat(bars.count + 1)) / CGFloat(bars.count))
            for (i, bar) in bars.enumerated() {
                let y = chartArea.minY + gap + CGFloat(i) * (barH + gap)
                let w = CGFloat(bar.value / maxVal) * (chartArea.width - labelWidth - 50)
                let r = CGRect(x: chartArea.minX + labelWidth, y: y, width: w, height: barH)

                ctx.setFillColor(bar.color.cgColor)
                ctx.fill(r)
                ctx.setStrokeColor(UIColor.black.cgColor)
                ctx.setLineWidth(barOutlineWidth)
                ctx.stroke(r)

                barRects.append((rect: r, label: bar.label, value: bar.value, color: bar.color))

                // Label left of bar
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 13),
                    .foregroundColor: UIColor.black
                ]
                let size = (bar.label as NSString).size(withAttributes: attrs)
                (bar.label as NSString).draw(at: CGPoint(x: chartArea.minX + labelWidth - size.width - 6, y: y + (barH - size.height) / 2), withAttributes: attrs)

                // Value right of bar
                let valStr = fmtVal(bar.value)
                let valAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 12),
                    .foregroundColor: UIColor.darkGray
                ]
                (valStr as NSString).draw(at: CGPoint(x: r.maxX + 6, y: y + (barH - 14) / 2), withAttributes: valAttrs)
            }
        }
    }

    // MARK: - Draw Pie Chart

    private func drawPieChart(ctx: CGContext, slices: [(label: String, value: Double, color: UIColor)], in area: CGRect) {
        pieSlices.removeAll()
        let total = slices.map(\.value).reduce(0, +)
        guard total > 0 else { return }

        let cx = area.midX, cy = area.midY
        let radius = min(area.width, area.height) / 2 - 10
        var startDeg: Double = 0

        for slice in slices {
            let sweepDeg = (slice.value / total) * 360
            let endDeg = startDeg + sweepDeg

            let startRad = (startDeg - 90) * .pi / 180
            let endRad = (endDeg - 90) * .pi / 180

            ctx.move(to: CGPoint(x: cx, y: cy))
            ctx.addArc(center: CGPoint(x: cx, y: cy), radius: radius, startAngle: startRad, endAngle: endRad, clockwise: false)
            ctx.closePath()
            ctx.setFillColor(slice.color.cgColor)
            ctx.fillPath()

            ctx.move(to: CGPoint(x: cx, y: cy))
            ctx.addArc(center: CGPoint(x: cx, y: cy), radius: radius, startAngle: startRad, endAngle: endRad, clockwise: false)
            ctx.closePath()
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(sliceSeparatorWidth)
            ctx.strokePath()

            let pct = (slice.value / total) * 100
            pieSlices.append((startAngle: startDeg, endAngle: endDeg, label: slice.label, value: slice.value, pct: pct, color: slice.color))

            // Label at midpoint of arc
            let midRad = ((startDeg + endDeg) / 2 - 90) * .pi / 180
            let labelR = radius * 0.65
            let lx = cx + labelR * cos(midRad)
            let ly = cy + labelR * sin(midRad)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: UIColor.white
            ]
            let text = "\(String(format: "%.0f", pct))%"
            let size = (text as NSString).size(withAttributes: attrs)
            (text as NSString).draw(at: CGPoint(x: lx - size.width / 2, y: ly - size.height / 2), withAttributes: attrs)

            startDeg = endDeg
        }
    }

    // MARK: - Draw Line Chart

    private func drawLineChart(ctx: CGContext, series: [(name: String, points: [(x: String, y: Double)], color: UIColor)], in area: CGRect) {
        lineSegments.removeAll()
        dataPoints.removeAll()

        let allY = series.flatMap { $0.points.map(\.y) }
        let yMin = allY.min() ?? 0, yMax = allY.max() ?? 1
        let yRange = yMax - yMin
        let yPad = yRange > 0 ? yRange * 0.1 : 1
        let maxPts = series.map(\.points.count).max() ?? 1

        // Grid
        ctx.setStrokeColor(UIColor.systemGray4.cgColor)
        ctx.setLineWidth(0.5)
        for i in 0...4 {
            let y = area.minY + area.height * CGFloat(i) / 4.0
            ctx.move(to: CGPoint(x: area.minX, y: y))
            ctx.addLine(to: CGPoint(x: area.maxX, y: y))
            ctx.strokePath()
        }

        // X-axis labels
        if let first = series.first {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray
            ]
            for (i, pt) in first.points.enumerated() {
                let x = area.minX + area.width * CGFloat(i) / CGFloat(max(1, maxPts - 1))
                let size = (pt.x as NSString).size(withAttributes: attrs)
                (pt.x as NSString).draw(at: CGPoint(x: x - size.width / 2, y: area.maxY + 4), withAttributes: attrs)
            }
        }

        for s in series {
            guard s.points.count > 1 else { continue }

            func mapPt(_ i: Int, _ pt: (x: String, y: Double)) -> CGPoint {
                let x = area.minX + area.width * CGFloat(i) / CGFloat(max(1, s.points.count - 1))
                let yNorm = yRange > 0 ? (pt.y - yMin + yPad) / (yRange + 2 * yPad) : 0.5
                let y = area.minY + area.height * (1 - CGFloat(yNorm))
                return CGPoint(x: x, y: y)
            }

            // Data lines — 4mm bold (primary data, same as SVG geometric edges)
            ctx.setStrokeColor(s.color.cgColor)
            ctx.setLineWidth(dataLineWidth)
            ctx.setLineCap(.round)
            for i in 0..<(s.points.count - 1) {
                let p1 = mapPt(i, s.points[i])
                let p2 = mapPt(i + 1, s.points[i + 1])
                ctx.move(to: p1)
                ctx.addLine(to: p2)
                ctx.strokePath()
                lineSegments.append((start: p1, end: p2))
            }

            // Data points — high-contrast red dots matching SVG vertex markers
            let markerColor = UIColor(red: 211/255, green: 47/255, blue: 47/255, alpha: 1.0)
            ctx.setFillColor(markerColor.cgColor)
            for (i, pt) in s.points.enumerated() {
                let c = mapPt(i, pt)
                let r = dataPointRadius
                ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                ctx.setStrokeColor(UIColor.white.cgColor)
                ctx.setLineWidth(2.0)
                ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
                dataPoints.append((center: c, label: pt.x, value: pt.y))
            }
        }
    }

    private func fmtVal(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}
