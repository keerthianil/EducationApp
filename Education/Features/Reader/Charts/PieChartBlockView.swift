//
//  PieChartBlockView.swift
//  Education
//
//  Accessible pie chart with visual rendering, haptic feedback,
//  slice-by-slice VoiceOver navigation, and data table alternative.
//

import SwiftUI
import Accessibility

struct PieChartBlockView: View {
    let title: String?
    let summary: String?
    let slices: [[String: Any]]

    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showDataTable = false
    @State private var showMultisensoryView = false

    private var chartSize: CGFloat {
        horizontalSizeClass == .regular ? 240 : 180
    }

    private var parsedSlices: [(label: String, value: Double, color: Color)] {
        slices.compactMap { dict in
            guard let label = dict["label"] as? String else { return nil }
            let value: Double
            if let v = dict["value"] as? Double { value = v }
            else if let v = dict["value"] as? Int { value = Double(v) }
            else { value = 0 }
            let colorHex = (dict["color"] as? String) ?? "#1C636F"
            return (label: label, value: value, color: Color(hex: colorHex))
        }
    }

    private var total: Double {
        parsedSlices.map(\.value).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if let t = title, !t.isEmpty {
                Text(t)
                    .font(.custom("Arial", size: 17).weight(.bold))
                    .foregroundColor(Color(hex: "#121417"))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityHeading(.h3)
            }

            if let s = summary, !s.isEmpty {
                Text(s)
                    .font(.custom("Arial", size: 14))
                    .foregroundColor(Color(hex: "#91949B"))
            }

            // Visual pie chart + legend — double tap for multisensory
            Button(action: openMultisensory) {
                ZStack {
                    HStack(alignment: .top, spacing: Spacing.medium) {
                        pieShape
                            .frame(width: chartSize, height: chartSize)

                        legend
                    }
                    Color.clear
                        .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chartAccessibilityLabel)
            .accessibilityHint("Double tap to access a multisensory representation.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: Text("Open")) {
                openMultisensory()
            }
            .accessibilityChartDescriptor(PieChartDescriptor(
                title: title,
                slices: parsedSlices.map { (label: $0.label, value: $0.value) },
                total: total
            ))
            .fullScreenCover(isPresented: $showMultisensoryView, onDismiss: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    UIAccessibility.post(notification: .screenChanged, argument: nil)
                }
            }) {
                MultisensoryChartView(
                    chartKind: .pie(
                        slices: parsedSlices.map { (label: $0.label, value: $0.value, color: UIColor($0.color)) }
                    ),
                    title: title
                )
                .environmentObject(haptics)
                .environmentObject(speech)
            }

            // Slice-by-slice VoiceOver navigation
            ForEach(Array(parsedSlices.enumerated()), id: \.offset) { index, slice in
                let pct = total > 0 ? (slice.value / total) * 100 : 0
                Color.clear
                    .frame(width: 0, height: 0)
                    .id("slice-\(index)")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(slice.label): \(formatValue(slice.value)), \(formatValue(pct)) percent")
                    .accessibilityValue("Slice \(index + 1) of \(parsedSlices.count)")
            }

            // Toggle data table
            Button {
                showDataTable.toggle()
                haptics.tapSelection()
                InteractionLogger.shared.logTap(
                    objectType: .chart,
                    label: "Toggle Data Table: \(title ?? "Pie Chart")"
                )
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showDataTable ? "chart.pie.fill" : "tablecells")
                        .font(.system(size: 14))
                    Text(showDataTable ? "Show Chart" : "Show Data Table")
                        .font(.custom("Arial", size: 14).weight(.medium))
                }
                .foregroundColor(ColorTokens.primary)
            }
            .accessibilityLabel(showDataTable ? "Switch to chart view" : "Switch to data table view")
            .accessibilityHint("Double tap to toggle between chart and table")

            if showDataTable {
                dataTableView
            }
        }
        .accessibilityRotor("Slices") {
            ForEach(Array(parsedSlices.enumerated()), id: \.offset) { index, slice in
                let pct = total > 0 ? (slice.value / total) * 100 : 0
                AccessibilityRotorEntry(
                    "\(slice.label): \(formatValue(pct)) percent",
                    id: "slice-\(index)"
                )
            }
        }
        .onAppear {
            InteractionLogger.shared.log(
                event: .voFocus,
                objectType: .chart,
                label: "Pie Chart Appeared: \(title ?? "Pie Chart")",
                location: .zero,
                additionalInfo: "\(parsedSlices.count) slices"
            )
        }
    }

    // MARK: - Multisensory

    private func openMultisensory() {
        haptics.tapSelection()
        InteractionLogger.shared.logTap(
            objectType: .chart,
            label: "Open Multisensory: \(title ?? "Pie Chart")"
        )
        showMultisensoryView = true
    }

    // MARK: - Chart Accessibility Label

    private var chartAccessibilityLabel: String {
        let sliceCount = parsedSlices.count
        var label = "Pie chart with \(sliceCount) slices."
        if let t = title { label = "\(t). " + label }
        if let largest = parsedSlices.max(by: { $0.value < $1.value }) {
            let pct = total > 0 ? (largest.value / total) * 100 : 0
            label += " Largest: \(largest.label) at \(formatValue(pct)) percent."
        }
        return label
    }

    // MARK: - Pie Shape

    private var pieShape: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 4
            var startAngle = Angle.degrees(-90)

            for slice in parsedSlices {
                let fraction = total > 0 ? slice.value / total : 0
                let sweep = Angle.degrees(fraction * 360)
                let endAngle = startAngle + sweep

                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius,
                           startAngle: startAngle, endAngle: endAngle, clockwise: false)
                path.closeSubpath()

                context.fill(path, with: .color(slice.color))
                context.stroke(path, with: .color(.white), lineWidth: 2)

                startAngle = endAngle
            }
        }
    }

    // MARK: - Legend

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parsedSlices.enumerated()), id: \.offset) { _, slice in
                let pct = total > 0 ? (slice.value / total) * 100 : 0
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(slice.color)
                        .frame(width: 12, height: 12)
                    Text("\(slice.label) (\(formatValue(pct))%)")
                        .font(.custom("Arial", size: horizontalSizeClass == .regular ? 13 : 11))
                        .foregroundColor(Color(hex: "#121417"))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Data Table

    private var dataTableView: some View {
        let tableRows = parsedSlices.map { slice -> [String] in
            let pct = total > 0 ? (slice.value / total) * 100 : 0
            return [slice.label, formatValue(slice.value), "\(formatValue(pct))%"]
        }
        return TableBlockView(
            title: nil,
            caption: nil,
            headers: ["Category", "Value", "Percentage"],
            rows: tableRows
        )
        .environmentObject(haptics)
    }

    private func formatValue(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

// MARK: - AXChartDescriptor for Audio Graphs
// Pie charts represented as categorical bars of percentages for sonification

private struct PieChartDescriptor: AXChartDescriptorRepresentable {
    let title: String?
    let slices: [(label: String, value: Double)]
    let total: Double

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Category",
            categoryOrder: slices.map(\.label)
        )

        let yAxis = AXNumericDataAxisDescriptor(
            title: "Percentage",
            range: 0...100,
            gridlinePositions: []
        ) { value in "\(Int(value))%" }

        let dataPoints = slices.map { slice in
            let pct = total > 0 ? (slice.value / total) * 100 : 0
            return AXDataPoint(x: slice.label, y: pct, label: "\(slice.label): \(Int(pct))%")
        }

        let series = AXDataSeriesDescriptor(
            name: title ?? "Pie Chart",
            isContinuous: false,
            dataPoints: dataPoints
        )

        return AXChartDescriptor(
            title: title ?? "Pie Chart",
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
