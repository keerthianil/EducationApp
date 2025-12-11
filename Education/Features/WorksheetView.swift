//
//  WorksheetView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/13/25.
//

import SwiftUI
import UIKit

/// Worksheet-style reader
/// - VoiceOver rotor handles char/word/line navigation natively
/// - Headers marked for rotor heading navigation
/// - Math pills are tappable buttons
/// - iPad compatible with adaptive layouts
struct WorksheetView: View {
    let title: String
    let pages: [[WorksheetItem]]

    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var currentPage: Int = 0
    
    // iPad-aware sizing
    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 800 : .infinity
    }
    
    private var horizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 48 : Spacing.screenPadding
    }
    
    private var titleFontSize: CGFloat {
        horizontalSizeClass == .regular ? 34 : 28
    }

    private var safePageIndex: Int {
        guard !pages.isEmpty else { return 0 }
        return min(max(currentPage, 0), pages.count - 1)
    }

    private var currentItems: [WorksheetItem] {
        guard pages.indices.contains(safePageIndex) else { return [] }
        return pages[safePageIndex]
    }

    var body: some View {
        ZStack {
            Color(hex: "#F5F5F5")
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {

                    // Title
                    Text(title)
                        .font(.custom("Arial", size: titleFontSize))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#121417"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Spacing.large)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityHeading(.h1)

                    // Page indicator
                    if !pages.isEmpty {
                        Text("Page \(safePageIndex + 1) of \(pages.count)")
                            .font(.custom("Arial", size: 13.5))
                            .foregroundColor(Color(hex: "#91949B"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, horizontalPadding)
                    }

                    // MAIN CONTENT
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        ForEach(currentItems) { item in
                            ForEach(Array(item.nodes.enumerated()), id: \.offset) { _, node in
                                if !shouldSkipQuestionHeading(node) {
                                    NodeBlockView(node: node)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)

                    // Page navigation buttons
                    if pages.count > 1 {
                        HStack {
                            Button {
                                moveToPreviousPage()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Prev Qn")
                                }
                                .font(.custom("Arial", size: 14).weight(.semibold))
                                .foregroundColor(ColorTokens.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(ColorTokens.primary, lineWidth: 1)
                                )
                            }
                            .disabled(safePageIndex == 0)
                            .opacity(safePageIndex == 0 ? 0.4 : 1.0)
                            .accessibilityLabel("Previous question")

                            Spacer()

                            Button {
                                moveToNextPage()
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Next Qn")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.custom("Arial", size: 14).weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(ColorTokens.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .disabled(safePageIndex == pages.count - 1)
                            .opacity(safePageIndex == pages.count - 1 ? 0.4 : 1.0)
                            .accessibilityLabel("Next question")
                        }
                        .padding(.horizontal, horizontalPadding)
                        .padding(.top, Spacing.large)
                    }
                }
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.bottom, Spacing.xLarge)
            }
        }
        .onAppear {
            announcePageChange()
        }
        .onChange(of: currentPage) { _ in
            announcePageChange()
        }
        .navigationTitle("Worksheet")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            speech.stop(immediate: true)
        }
    }

    // MARK: - Helpers

    private func moveToNextPage() {
        guard safePageIndex + 1 < pages.count else { return }
        haptics.pageChange()
        currentPage = safePageIndex + 1
    }

    private func moveToPreviousPage() {
        guard safePageIndex > 0 else { return }
        haptics.pageChange()
        currentPage = safePageIndex - 1
    }

    private func announcePageChange() {
        guard !pages.isEmpty else { return }
        haptics.sectionChange()
        
        if UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Page \(safePageIndex + 1) of \(pages.count)"
                )
            }
        }
    }

    private func shouldSkipQuestionHeading(_ node: Node) -> Bool {
        if case .heading(_, let text) = node {
            return isQuestionHeading(text)
        }
        return false
    }

    private func isQuestionHeading(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.hasPrefix("question ") ||
               lower.hasPrefix("q.") ||
               lower.hasPrefix("q ")
    }
}

// MARK: - Node Block View

private struct NodeBlockView: View {
    let node: Node
    
    @EnvironmentObject var haptics: HapticService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var contentPadding: CGFloat {
        horizontalSizeClass == .regular ? Spacing.large : Spacing.medium
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            nodeContent
        }
        .padding(contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    @ViewBuilder
    private var nodeContent: some View {
        switch node {
        case .heading(let level, let text):
            Text(text)
                .font(.custom("Arial", size: headingSize(for: level)))
                .fontWeight(level <= 2 ? .bold : .semibold)
                .foregroundColor(Color(hex: "#121417"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(level == 1 ? .h1 : level == 2 ? .h2 : .h3)

        case .paragraph(let items):
            ParagraphBlockView(items: items)

        case .image(let src, let alt):
            ImageBlockView(dataURI: src, alt: alt)

        case .svgNode(let svg, let title, let summaries):
            SVGBlockView(svg: svg, title: title, summaries: summaries)

        case .unknown:
            EmptyView()
        }
    }
    
    private func headingSize(for level: Int) -> CGFloat {
        let baseSize: CGFloat = horizontalSizeClass == .regular ? 26 : 22
        switch level {
        case 1: return baseSize
        case 2: return baseSize - 2
        default: return baseSize - 4
        }
    }
}

// MARK: - Paragraph Block

private struct ParagraphBlockView: View {
    let items: [Inline]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var textParts: [String] {
        items.compactMap { inline -> String? in
            if case .text(let t) = inline { return t }
            return nil
        }
    }
    
    private var mathParts: [(Int, Inline)] {
        items.enumerated().compactMap { idx, inline in
            if case .math = inline { return (idx, inline) }
            return nil
        }
    }
    
    private var bodyFontSize: CGFloat {
        horizontalSizeClass == .regular ? 19 : 17
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let combinedText = textParts.joined()
            if !combinedText.isEmpty {
                Text(combinedText)
                    .font(.custom("Arial", size: bodyFontSize))
                    .foregroundColor(Color(hex: "#121417"))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(combinedText)
            }
            
            ForEach(mathParts, id: \.0) { _, mathInline in
                if case .math(let latex, let mathml, let display) = mathInline {
                    MathEquationPill(latex: latex, mathml: mathml, display: display)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Math Equation Pill

private struct MathEquationPill: View {
    let latex: String?
    let mathml: String?
    let display: String?
    
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @EnvironmentObject var speech: SpeechService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var displayText: String {
        let text = latex ?? mathml ?? "Equation"
        if text.count > 50 {
            return String(text.prefix(47)) + "..."
        }
        return text
    }
    
    private var spokenString: String {
        if let l = latex, !l.isEmpty {
            return mathSpeech.speakable(from: l, verbosity: .verbose)
        }
        if let m = mathml, !m.isEmpty {
            return mathSpeech.speakable(from: m, verbosity: .verbose)
        }
        return "equation"
    }
    
    private var pillFontSize: CGFloat {
        horizontalSizeClass == .regular ? 17 : 15
    }
    
    var body: some View {
        Button {
            haptics.mathStart()
            
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement, argument: spokenString)
            } else {
                speech.speak(spokenString)
            }
            
            haptics.mathEnd()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "function")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(ColorTokens.primary)
                
                Text(displayText)
                    .font(.custom("Arial", size: pillFontSize))
                    .foregroundColor(Color(hex: "#121417"))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.primaryLight3)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Equation")
        .accessibilityHint("Double tap to hear the math equation read aloud")
        .accessibilityAddTraits(.startsMediaSession)
        .onAppear {
            if UIAccessibility.isVoiceOverRunning {
                haptics.mathTerm()
            }
        }
    }
}

// MARK: - Image Block

private struct ImageBlockView: View {
    let dataURI: String
    let alt: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var imageHeight: CGFloat {
        horizontalSizeClass == .regular ? 300 : 160
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let img = decodeImage(dataURI: dataURI) {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(img.size, contentMode: .fit)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(alt ?? "Image")
            } else {
                Rectangle()
                    .fill(Color(hex: "#DEECF8"))
                    .frame(height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(alt ?? "Image")
            }
            
            if let altText = alt, !altText.isEmpty {
                Button {
                    if UIAccessibility.isVoiceOverRunning {
                        UIAccessibility.post(notification: .announcement, argument: altText)
                    }
                } label: {
                    Text("View Description")
                        .font(.custom("Arial", size: 14))
                        .foregroundColor(ColorTokens.primary)
                }
                .accessibilityLabel("View image description")
                .accessibilityHint("Double tap to hear: \(altText)")
            }
        }
    }
    
    private func decodeImage(dataURI: String) -> UIImage? {
        guard let range = dataURI.range(of: "base64,") else { return nil }
        let base64 = String(dataURI[range.upperBound...])
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - SVG Block

private struct SVGBlockView: View {
    let svg: String
    let title: String?
    let summaries: [String]?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var svgHeight: CGFloat {
        horizontalSizeClass == .regular ? 300 : 200
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            if let t = title {
                Text(t)
                    .font(.custom("Arial", size: 17).weight(.bold))
                    .foregroundColor(Color(hex: "#121417"))
                    .accessibilityAddTraits(.isHeader)
            }

            SVGView(svg: svg)
                .frame(maxWidth: .infinity)
                .frame(height: svgHeight)
                .accessibilityHidden(true)

            if let desc = summaries?.first {
                Text(desc)
                    .font(.custom("Arial", size: 13))
                    .foregroundColor(Color(hex: "#61758A"))
            }
            
            Button {
                if let desc = summaries?.first, UIAccessibility.isVoiceOverRunning {
                    UIAccessibility.post(notification: .announcement, argument: desc)
                }
            } label: {
                Text("View Description")
                    .font(.custom("Arial", size: 14))
                    .foregroundColor(ColorTokens.primary)
            }
            .accessibilityLabel("View graphic description")
        }
        .accessibilityElement(children: .contain)
    }
}
