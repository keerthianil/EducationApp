//
//  BarChartBlockView.swift
//  Education
//
//  Accessible bar chart with visual rendering, haptic feedback,
//  bar-by-bar VoiceOver navigation, and data table alternative.
//

import SwiftUI
import Accessibility

struct BarChartBlockView: View {
    let title: String?
    let summary: String?
    let xAxisLabel: String?
    let yAxisLabel: String?
    let orientation: String?
    let bars: [[String: Any]]

    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showDataTable = false
    @State private var showMultisensoryView = false

    private var isVertical: Bool {
        orientation?.lowercased() != "horizontal"
    }

    private var chartHeight: CGFloat {
        horizontalSizeClass == .regular ? 300 : 220
    }

    private var parsedBars: [(label: String, value: Double, color: Color)] {
        bars.compactMap { dict in
            guard let label = dict["label"] as? String else { return nil }
            let value: Double
            if let v = dict["value"] as? Double { value = v }
            else if let v = dict["value"] as? Int { value = Double(v) }
            else { value = 0 }
            let colorHex = (dict["color"] as? String) ?? "#1C636F"
            return (label: label, value: value, color: Color(hex: colorHex))
        }
    }

    private var maxValue: Double {
        parsedBars.map(\.value).max() ?? 1
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

            // Visual chart with summary label for VoiceOver — double tap for multisensory
            Button(action: openMultisensory) {
                ZStack {
                    Group {
                        if isVertical {
                            verticalChart
                        } else {
                            horizontalChart
                        }
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
            .accessibilityChartDescriptor(BarChartDescriptor(
                title: title, xAxisLabel: xAxisLabel, yAxisLabel: yAxisLabel,
                bars: parsedBars.map { (label: $0.label, value: $0.value) }
            ))
            .fullScreenCover(isPresented: $showMultisensoryView, onDismiss: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    UIAccessibility.post(notification: .screenChanged, argument: nil)
                }
            }) {
                MultisensoryChartView(
                    chartKind: .bar(
                        bars: parsedBars.map { (label: $0.label, value: $0.value, color: UIColor($0.color)) },
                        isVertical: isVertical
                    ),
                    title: title
                )
                .environmentObject(haptics)
                .environmentObject(speech)
            }

            // Bar-by-bar VoiceOver navigation
            ForEach(Array(parsedBars.enumerated()), id: \.offset) { index, bar in
                Color.clear
                    .frame(width: 0, height: 0)
                    .id("bar-\(index)")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(bar.label): \(formatValue(bar.value))")
                    .accessibilityValue("Bar \(index + 1) of \(parsedBars.count)")
            }

            // Toggle data table
            Button {
                showDataTable.toggle()
                haptics.tapSelection()
                InteractionLogger.shared.logTap(
                    objectType: .chart,
                    label: "Toggle Data Table: \(title ?? "Bar Chart")"
                )
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showDataTable ? "chart.bar.fill" : "tablecells")
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
        .accessibilityRotor("Bars") {
            ForEach(Array(parsedBars.enumerated()), id: \.offset) { index, bar in
                AccessibilityRotorEntry("\(bar.label): \(formatValue(bar.value))", id: "bar-\(index)")
            }
        }
        .onAppear {
            InteractionLogger.shared.log(
                event: .voFocus,
                objectType: .chart,
                label: "Bar Chart Appeared: \(title ?? "Bar Chart")",
                location: .zero,
                additionalInfo: "\(parsedBars.count) bars, orientation: \(orientation ?? "vertical")"
            )
        }
    }

    // MARK: - Multisensory

    private func openMultisensory() {
        haptics.tapSelection()
        InteractionLogger.shared.logTap(
            objectType: .chart,
            label: "Open Multisensory: \(title ?? "Bar Chart")"
        )
        showMultisensoryView = true
    }

    // MARK: - Chart Accessibility Label

    private var chartAccessibilityLabel: String {
        let barCount = parsedBars.count
        let dir = isVertical ? "vertical" : "horizontal"
        var label = "\(dir) bar chart with \(barCount) bars."
        if let t = title { label = "\(t). " + label }
        if let maxBar = parsedBars.max(by: { $0.value < $1.value }) {
            label += " Highest value: \(maxBar.label) at \(formatValue(maxBar.value))."
        }
        return label
    }

    // MARK: - Vertical Bar Chart

    private var verticalChart: some View {
        VStack(spacing: Spacing.xxSmall) {
            if let y = yAxisLabel {
                Text(y)
                    .font(.custom("Arial", size: 12))
                    .foregroundColor(Color(hex: "#91949B"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .bottom, spacing: horizontalSizeClass == .regular ? 12 : 6) {
                ForEach(Array(parsedBars.enumerated()), id: \.offset) { _, bar in
                    VStack(spacing: 4) {
                        Text(formatValue(bar.value))
                            .font(.custom("Arial", size: 10))
                            .foregroundColor(Color(hex: "#91949B"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(bar.color)
                            .frame(height: max(4, CGFloat(bar.value / maxValue) * chartHeight))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: chartHeight)
            .padding(.horizontal, 4)

            HStack(spacing: horizontalSizeClass == .regular ? 12 : 6) {
                ForEach(Array(parsedBars.enumerated()), id: \.offset) { _, bar in
                    Text(bar.label)
                        .font(.custom("Arial", size: horizontalSizeClass == .regular ? 11 : 9))
                        .foregroundColor(Color(hex: "#121417"))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)

            if let x = xAxisLabel {
                Text(x)
                    .font(.custom("Arial", size: 12))
                    .foregroundColor(Color(hex: "#91949B"))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(Spacing.small)
        .background(Color(hex: "#F9FAFB"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Horizontal Bar Chart

    private var horizontalChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parsedBars.enumerated()), id: \.offset) { _, bar in
                HStack(spacing: 8) {
                    Text(bar.label)
                        .font(.custom("Arial", size: 12))
                        .foregroundColor(Color(hex: "#121417"))
                        .frame(width: horizontalSizeClass == .regular ? 120 : 80, alignment: .trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(bar.color)
                            .frame(width: max(4, CGFloat(bar.value / maxValue) * geo.size.width))
                    }
                    .frame(height: 28)

                    Text(formatValue(bar.value))
                        .font(.custom("Arial", size: 12))
                        .foregroundColor(Color(hex: "#91949B"))
                        .frame(width: 40, alignment: .leading)
                }
            }

            if let x = xAxisLabel {
                Text(x)
                    .font(.custom("Arial", size: 12))
                    .foregroundColor(Color(hex: "#91949B"))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
        .padding(Spacing.small)
        .background(Color(hex: "#F9FAFB"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Data Table Alternative

    private var dataTableView: some View {
        TableBlockView(
            title: nil,
            caption: nil,
            headers: [xAxisLabel ?? "Category", yAxisLabel ?? "Value"],
            rows: parsedBars.map { [$0.label, formatValue($0.value)] }
        )
        .environmentObject(haptics)
    }

    private func formatValue(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

// MARK: - AXChartDescriptor for Audio Graphs

private struct BarChartDescriptor: AXChartDescriptorRepresentable {
    let title: String?
    let xAxisLabel: String?
    let yAxisLabel: String?
    let bars: [(label: String, value: Double)]

    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: xAxisLabel ?? "Category",
            categoryOrder: bars.map(\.label)
        )

        let maxVal = bars.map(\.value).max() ?? 1
        let yAxis = AXNumericDataAxisDescriptor(
            title: yAxisLabel ?? "Value",
            range: 0...maxVal,
            gridlinePositions: []
        ) { value in
            value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
        }

        let dataPoints = bars.map { bar in
            AXDataPoint(x: bar.label, y: bar.value, label: "\(bar.label): \(bar.value == bar.value.rounded() ? "\(Int(bar.value))" : String(format: "%.1f", bar.value))")
        }

        let series = AXDataSeriesDescriptor(
            name: title ?? "Bar Chart",
            isContinuous: false,
            dataPoints: dataPoints
        )

        return AXChartDescriptor(
            title: title ?? "Bar Chart",
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
