//
//  LineGraphBlockView.swift
//  Education
//
//  Accessible line graph with visual rendering, haptic feedback,
//  point-by-point VoiceOver navigation, and data table alternative.
//

import SwiftUI
import Accessibility

struct LineGraphBlockView: View {
    let title: String?
    let summary: String?
    let xAxisLabel: String?
    let yAxisLabel: String?
    let series: [[String: Any]]

    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showDataTable = false
    @State private var showMultisensoryView = false

    private var chartHeight: CGFloat {
        horizontalSizeClass == .regular ? 280 : 200
    }

    private struct DataPoint: Identifiable {
        let id = UUID()
        let x: String
        let y: Double
    }

    private struct SeriesData: Identifiable {
        let id = UUID()
        let name: String
        let points: [DataPoint]
        let color: Color
    }

    private var parsedSeries: [SeriesData] {
        let defaultColors: [String] = ["#1C636F", "#E8734A", "#4A90D9", "#208515", "#B31111"]
        return series.enumerated().compactMap { index, dict in
            let name = (dict["name"] as? String) ?? "Series \(index + 1)"
            let colorHex = (dict["color"] as? String) ?? defaultColors[index % defaultColors.count]
            guard let pointDicts = dict["points"] as? [[String: Any]] else { return nil }
            let points = pointDicts.compactMap { pd -> DataPoint? in
                let x: String
                if let xStr = pd["x"] as? String { x = xStr }
                else if let xNum = pd["x"] as? Double { x = String(format: "%.0f", xNum) }
                else if let xInt = pd["x"] as? Int { x = String(xInt) }
                else { return nil }

                let y: Double
                if let yD = pd["y"] as? Double { y = yD }
                else if let yI = pd["y"] as? Int { y = Double(yI) }
                else { return nil }

                return DataPoint(x: x, y: y)
            }
            return SeriesData(name: name, points: points, color: Color(hex: colorHex))
        }
    }

    private var allYValues: [Double] {
        parsedSeries.flatMap { $0.points.map(\.y) }
    }

    private var yMin: Double { allYValues.min() ?? 0 }
    private var yMax: Double { allYValues.max() ?? 1 }

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

            // Visual line graph — double tap for multisensory
            Button(action: openMultisensory) {
                ZStack {
                    lineChartView
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
            .accessibilityChartDescriptor(LineChartDescriptor(
                title: title, xAxisLabel: xAxisLabel, yAxisLabel: yAxisLabel,
                series: parsedSeries.map { s in
                    (name: s.name, points: s.points.map { (x: $0.x, y: $0.y) })
                }
            ))
            .fullScreenCover(isPresented: $showMultisensoryView, onDismiss: {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    UIAccessibility.post(notification: .screenChanged, argument: nil)
                }
            }) {
                MultisensoryChartView(
                    chartKind: .line(
                        series: parsedSeries.map { s in
                            (name: s.name, points: s.points.map { (x: $0.x, y: $0.y) }, color: UIColor(s.color))
                        }
                    ),
                    title: title
                )
                .environmentObject(haptics)
                .environmentObject(speech)
            }

            // Point-by-point VoiceOver navigation
            ForEach(parsedSeries) { seriesItem in
                VStack(alignment: .leading, spacing: 0) {
                    if parsedSeries.count > 1 {
                        Text(seriesItem.name)
                            .font(.custom("Arial", size: 13).weight(.semibold))
                            .foregroundColor(Color(hex: "#121417"))
                            .accessibilityAddTraits(.isHeader)
                    }
                    ForEach(Array(seriesItem.points.enumerated()), id: \.offset) { index, point in
                        Color.clear
                            .frame(width: 0, height: 0)
                            .id("point-\(seriesItem.name)-\(index)")
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(point.x): \(formatValue(point.y))")
                            .accessibilityValue("Point \(index + 1) of \(seriesItem.points.count)")
                    }
                }
            }

            // Toggle data table
            Button {
                showDataTable.toggle()
                haptics.tapSelection()
                InteractionLogger.shared.logTap(
                    objectType: .chart,
                    label: "Toggle Data Table: \(title ?? "Line Graph")"
                )
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showDataTable ? "chart.xyaxis.line" : "tablecells")
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
        .accessibilityRotor("Data Points") {
            ForEach(parsedSeries) { seriesItem in
                ForEach(Array(seriesItem.points.enumerated()), id: \.offset) { index, point in
                    AccessibilityRotorEntry(
                        "\(point.x): \(formatValue(point.y))",
                        id: "point-\(seriesItem.name)-\(index)"
                    )
                }
            }
        }
        .onAppear {
            InteractionLogger.shared.log(
                event: .voFocus,
                objectType: .chart,
                label: "Line Graph Appeared: \(title ?? "Line Graph")",
                location: .zero,
                additionalInfo: "\(parsedSeries.count) series, \(parsedSeries.first?.points.count ?? 0) points"
            )
        }
    }

    // MARK: - Multisensory

    private func openMultisensory() {
        haptics.tapSelection()
        InteractionLogger.shared.logTap(
            objectType: .chart,
            label: "Open Multisensory: \(title ?? "Line Graph")"
        )
        showMultisensoryView = true
    }

    // MARK: - Chart Accessibility Label

    private var chartAccessibilityLabel: String {
        let seriesCount = parsedSeries.count
        let pointCount = parsedSeries.first?.points.count ?? 0
        var label = "Line graph with \(seriesCount) series and \(pointCount) data points."
        if let t = title { label = "\(t). " + label }
        if let first = parsedSeries.first?.points.first,
           let last = parsedSeries.first?.points.last {
            let trend = last.y > first.y ? "upward" : last.y < first.y ? "downward" : "flat"
            label += " Trend: \(trend) from \(formatValue(first.y)) to \(formatValue(last.y))."
        }
        return label
    }

    // MARK: - Line Chart Drawing

    private var lineChartView: some View {
        VStack(spacing: Spacing.xxSmall) {
            if let y = yAxisLabel {
                Text(y)
                    .font(.custom("Arial", size: 12))
                    .foregroundColor(Color(hex: "#91949B"))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            GeometryReader { geo in
                let plotWidth = geo.size.width
                let plotHeight = geo.size.height
                let yRange = yMax - yMin
                let yPadding = yRange > 0 ? yRange * 0.1 : 1

                ZStack {
                    ForEach(0..<5, id: \.self) { i in
                        let frac = CGFloat(i) / 4.0
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: frac * plotHeight))
                            path.addLine(to: CGPoint(x: plotWidth, y: frac * plotHeight))
                        }
                        .stroke(Color(hex: "#DADDE2").opacity(0.5), lineWidth: 0.5)
                    }

                    ForEach(parsedSeries) { seriesItem in
                        let points = seriesItem.points
                        if points.count > 1 {
                            Path { path in
                                for (i, pt) in points.enumerated() {
                                    let x = plotWidth * CGFloat(i) / CGFloat(points.count - 1)
                                    let yNorm = yRange > 0 ? (pt.y - yMin + yPadding) / (yRange + 2 * yPadding) : 0.5
                                    let y = plotHeight * (1 - CGFloat(yNorm))
                                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                                }
                            }
                            .stroke(seriesItem.color, lineWidth: 2.5)

                            ForEach(Array(points.enumerated()), id: \.offset) { i, pt in
                                let x = plotWidth * CGFloat(i) / CGFloat(points.count - 1)
                                let yNorm = yRange > 0 ? (pt.y - yMin + yPadding) / (yRange + 2 * yPadding) : 0.5
                                let y = plotHeight * (1 - CGFloat(yNorm))
                                Circle()
                                    .fill(seriesItem.color)
                                    .frame(width: 8, height: 8)
                                    .position(x: x, y: y)
                            }
                        }
                    }
                }
            }
            .frame(height: chartHeight)

            if let firstSeries = parsedSeries.first {
                HStack(spacing: 0) {
                    ForEach(Array(firstSeries.points.enumerated()), id: \.offset) { _, pt in
                        Text(pt.x)
                            .font(.custom("Arial", size: horizontalSizeClass == .regular ? 11 : 9))
                            .foregroundColor(Color(hex: "#91949B"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

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

    // MARK: - Data Table

    private var dataTableView: some View {
        let firstSeries = parsedSeries.first
        let xLabels = firstSeries?.points.map(\.x) ?? []

        if parsedSeries.count == 1, let s = firstSeries {
            return AnyView(
                TableBlockView(
                    title: nil,
                    caption: nil,
                    headers: [xAxisLabel ?? "X", yAxisLabel ?? "Value"],
                    rows: s.points.map { [$0.x, formatValue($0.y)] }
                )
                .environmentObject(haptics)
            )
        } else {
            var tableHeaders = [xAxisLabel ?? "X"]
            tableHeaders.append(contentsOf: parsedSeries.map(\.name))
            let tableRows = xLabels.enumerated().map { i, x -> [String] in
                var row = [x]
                for s in parsedSeries {
                    if i < s.points.count {
                        row.append(formatValue(s.points[i].y))
                    } else {
                        row.append("-")
                    }
                }
                return row
            }
            return AnyView(
                TableBlockView(
                    title: nil,
                    caption: nil,
                    headers: tableHeaders,
                    rows: tableRows
                )
                .environmentObject(haptics)
            )
        }
    }

    private func formatValue(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

// MARK: - AXChartDescriptor for Audio Graphs

private struct LineChartDescriptor: AXChartDescriptorRepresentable {
    let title: String?
    let xAxisLabel: String?
    let yAxisLabel: String?
    let series: [(name: String, points: [(x: String, y: Double)])]

    func makeChartDescriptor() -> AXChartDescriptor {
        let allLabels = series.first?.points.map(\.x) ?? []
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: xAxisLabel ?? "X",
            categoryOrder: allLabels
        )

        let allY = series.flatMap { $0.points.map(\.y) }
        let yMin = allY.min() ?? 0
        let yMax = allY.max() ?? 1
        let yAxis = AXNumericDataAxisDescriptor(
            title: yAxisLabel ?? "Value",
            range: yMin...yMax,
            gridlinePositions: []
        ) { value in
            value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
        }

        let descriptors = series.map { s in
            AXDataSeriesDescriptor(
                name: s.name,
                isContinuous: true,
                dataPoints: s.points.map { pt in
                    AXDataPoint(x: pt.x, y: pt.y, label: "\(pt.x): \(pt.y == pt.y.rounded() ? "\(Int(pt.y))" : String(format: "%.1f", pt.y))")
                }
            )
        }

        return AXChartDescriptor(
            title: title ?? "Line Graph",
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: descriptors
        )
    }
}
