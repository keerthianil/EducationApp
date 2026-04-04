//
//  TableBlockView.swift
//  Education
//
//  Accessible data table with cell-by-cell VoiceOver navigation,
//  custom rotors for row/column traversal, and haptic feedback.
//

import SwiftUI
import Accessibility

struct TableBlockView: View {
    let title: String?
    let caption: String?
    let headers: [String]
    let rows: [[String]]

    @EnvironmentObject var haptics: HapticService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var bodyFontSize: CGFloat {
        horizontalSizeClass == .regular ? 16 : 14
    }

    private var headerFontSize: CGFloat {
        horizontalSizeClass == .regular ? 16 : 14
    }

    private var cellWidth: CGFloat {
        let colCount = max(headers.count, 1)
        if horizontalSizeClass == .regular {
            return max(120, 700 / CGFloat(colCount))
        }
        return max(100, 340 / CGFloat(colCount))
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

            Text(tableSummary)
                .font(.custom("Arial", size: 13))
                .foregroundColor(Color(hex: "#91949B"))
                .accessibilityLabel(tableSummary)

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    if !headers.isEmpty {
                        headerRow
                    }
                    dataRows
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let c = caption, !c.isEmpty {
                Text(c)
                    .font(.custom("Arial", size: 13))
                    .foregroundColor(Color(hex: "#91949B"))
                    .accessibilityLabel("Source: \(c)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityRotor("Rows") {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                let firstCell = row.first ?? ""
                let label = headers.isEmpty ? "Row \(rowIndex + 1)" : "\(headers[0]): \(firstCell)"
                AccessibilityRotorEntry(label, id: "row-\(rowIndex)")
            }
        }
        .accessibilityHint("Use the Rows rotor to navigate between rows")
        .onAppear {
            InteractionLogger.shared.log(
                event: .voFocus,
                objectType: .table,
                label: "Table Appeared: \(title ?? "Data Table")",
                location: .zero,
                additionalInfo: "\(rows.count) rows, \(headers.count) columns"
            )
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(headers.enumerated()), id: \.offset) { colIndex, header in
                Text(header)
                    .font(.custom("Arial", size: headerFontSize).weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(width: cellWidth, alignment: .leading)
                    .background(ColorTokens.primary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Column header: \(header)")
                    .accessibilityAddTraits(.isHeader)

                if colIndex < headers.count - 1 {
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 1)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    // MARK: - Data Rows

    private var dataRows: some View {
        ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                        let headerLabel = colIndex < headers.count ? headers[colIndex] : "Column \(colIndex + 1)"
                        Text(cell)
                            .font(.custom("Arial", size: bodyFontSize))
                            .foregroundColor(Color(hex: "#121417"))
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(width: cellWidth, alignment: .leading)
                            .background(rowIndex % 2 == 0 ? Color.white : Color(hex: "#F5F5F5"))
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Row \(rowIndex + 1), \(headerLabel): \(cell)")
                    }
                }
                .id("row-\(rowIndex)")

                if rowIndex < rows.count - 1 {
                    Rectangle()
                        .fill(Color(hex: "#DADDE2"))
                        .frame(height: 1)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private var tableSummary: String {
        let colCount = headers.count
        let rowCount = rows.count
        if let t = title {
            return "\(t). Data table with \(rowCount) rows and \(colCount) columns."
        }
        return "Data table with \(rowCount) rows and \(colCount) columns."
    }
}
