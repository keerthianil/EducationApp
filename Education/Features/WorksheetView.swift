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
struct WorksheetView: View {
    let title: String
    let pages: [[WorksheetItem]]

    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage: Int = 0

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

                    // Title - centered, Arial bold per Figma
                    Text(title)
                        .font(.custom("Arial", size: 28))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#121417"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Spacing.large)
                        // Header trait - rotor can navigate to this
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityHeading(.h1)

                    // Page indicator
                    if !pages.isEmpty {
                        Text("Page \(safePageIndex + 1) of \(pages.count)")
                            .font(.custom("Arial", size: 13.5))
                            .foregroundColor(Color(hex: "#91949B"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Spacing.screenPadding)
                    }

                    // MAIN CONTENT - proper semantic structure for VoiceOver rotor
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        ForEach(currentItems) { item in
                            ForEach(Array(item.nodes.enumerated()), id: \.offset) { _, node in
                                if !shouldSkipQuestionHeading(node) {
                                    NodeBlockView(node: node)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.screenPadding)

                    // Page navigation buttons per Figma
                    if pages.count > 1 {
                        HStack {
                            // Previous - bordered secondary style
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

                            // Next - filled primary style
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
                        .padding(.horizontal, Spacing.screenPadding)
                        .padding(.top, Spacing.large)
                    }
                }
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
        
        // VoiceOver announcement for page change
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

// MARK: - Node Block View (White cards with stroke per Figma)

private struct NodeBlockView: View {
    let node: Node
    
    @EnvironmentObject var haptics: HapticService

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            nodeContent
        }
        .padding(Spacing.medium)
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
            // HEADER: VoiceOver rotor can navigate by headings
            // Rotor skips char/word/line for headers (they're navigation landmarks)
            Text(text)
                .font(.custom("Arial", size: level == 1 ? 22 : level == 2 ? 20 : 18))
                .fontWeight(level <= 2 ? .bold : .semibold)
                .foregroundColor(Color(hex: "#121417"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(level == 1 ? .h1 : level == 2 ? .h2 : .h3)

        case .paragraph(let items):
            // PARAGRAPH: VoiceOver rotor CAN do char/word/line navigation
            // This is where detailed reading happens
            ParagraphBlockView(items: items)

        case .image(let src, let alt):
            ImageBlockView(dataURI: src, alt: alt)

        case .svgNode(let svg, let title, let summaries):
            SVGBlockView(svg: svg, title: title, summaries: summaries)

        case .unknown:
            EmptyView()
        }
    }
}

// MARK: - Paragraph Block with proper VoiceOver semantics

/// Paragraphs are the main content - VoiceOver rotor works here
/// User can:
/// - Two-finger rotate to select "Characters", "Words", or "Lines"
/// - Swipe up/down to navigate by that unit
/// - Two-finger swipe down to read all continuously
private struct ParagraphBlockView: View {
    let items: [Inline]
    
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Text content - THIS is where VoiceOver rotor char/word/line works
            let combinedText = textParts.joined()
            if !combinedText.isEmpty {
                Text(combinedText)
                    .font(.custom("Arial", size: 17))
                    .foregroundColor(Color(hex: "#121417"))
                    // These modifiers enable proper rotor behavior
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(combinedText)
                    // Allow VoiceOver to treat this as readable text
                    // Rotor will offer Characters, Words, Lines options
            }
            
            // Math equations displayed BELOW text, each tappable
            ForEach(mathParts, id: \.0) { _, mathInline in
                if case .math(let latex, let mathml, let display) = mathInline {
                    MathEquationPill(latex: latex, mathml: mathml, display: display)
                }
            }
        }
        // Container for the paragraph - VoiceOver navigates into it
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Math Equation Pill (Tappable button)

/// Math pills are buttons - double tap to hear equation
/// Haptic pulse signals math content
private struct MathEquationPill: View {
    let latex: String?
    let mathml: String?
    let display: String?
    
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @EnvironmentObject var speech: SpeechService
    
    private var displayText: String {
        // Show simplified version visually
        let text = latex ?? mathml ?? "Equation"
        // Truncate for display if too long
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
    
    var body: some View {
        Button {
            // Haptic pulse for math content (per use case)
            haptics.mathStart()
            
            // Speak the equation
            if UIAccessibility.isVoiceOverRunning {
                // Post as announcement so it queues after VoiceOver
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
                    .font(.custom("Arial", size: 15))
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
            // Brief haptic when math content comes into view (for VoiceOver users)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
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
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(alt ?? "Image")
            }
            
            // View Description button per Figma
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
                .frame(height: 200)
                .accessibilityHidden(true) // SVG itself hidden, we provide text description

            if let desc = summaries?.first {
                Text(desc)
                    .font(.custom("Arial", size: 13))
                    .foregroundColor(Color(hex: "#61758A"))
            }
            
            // View Description button
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
