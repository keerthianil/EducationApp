//
//  WorksheetView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/13/25.
//
//

import SwiftUI
import UIKit
import Foundation
import WebKit

struct WorksheetView: View {
    let title: String
    let pages: [[WorksheetItem]]

    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var currentPage: Int = 0
<<<<<<< HEAD
    @State private var isNavigating: Bool = false
    @AccessibilityFocusState private var isBackButtonFocused: Bool
=======
>>>>>>> feature/map-style-svg-rendering
    
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
    
    private var canGoPrevious: Bool {
        safePageIndex > 0
    }
    
    private var canGoNext: Bool {
        safePageIndex < pages.count - 1
    }

    var body: some View {
        worksheetContent
            .onThreeFingerSwipeBack {
                speech.stop(immediate: true)
                InteractionLogger.shared.log(
                    event: .threeFingerSwipe,
                    objectType: .background,
                    label: "Three Finger Back",
                    location: .zero,
                    additionalInfo: "Dismissed WorksheetView"
                )
                dismiss()
            }
    }
    
    private var worksheetContent: some View {
        ZStack {
            Color(hex: "#F5F5F5")
                .ignoresSafeArea()

            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        Color.clear
                            .frame(height: 1)
                            .id("topAnchor")

                        if !pages.isEmpty {
                            Text("Page \(safePageIndex + 1) of \(pages.count)")
                                .font(.custom("Arial", size: 13.5))
                                .foregroundColor(Color(hex: "#91949B"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, horizontalPadding)
                                .accessibilityHidden(true)
                        }

                        // FIX: .id(currentPage) forces SwiftUI to rebuild content on page change
                        VStack(alignment: .leading, spacing: Spacing.medium) {
                            ForEach(currentItems) { item in
                                ForEach(Array(item.nodes.enumerated()), id: \.offset) { _, node in
                                    if !shouldSkipHeading(node) {
                                        NodeBlockView(node: node)
                                            .environmentObject(haptics)
                                            .environmentObject(mathSpeech)
                                            .environmentObject(speech)
                                    }
                                }
                            }
                        }
                        .id(currentPage) // <-- KEY FIX: forces fresh render on page change
                        .padding(.horizontal, horizontalPadding)

                        if pages.count > 1 {
                            navigationButtons(scrollProxy: scrollProxy)
                        }
                    }
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, Spacing.xLarge)
                }
            }
        }
<<<<<<< HEAD
        .onAppear {
            InteractionLogger.shared.setCurrentScreen("WorksheetView: \(title)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isBackButtonFocused = true
            }
=======
        .onChange(of: currentPage) { _ in
            announcePageChange()
>>>>>>> feature/map-style-svg-rendering
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(title)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    speech.stop(immediate: true)
                    InteractionLogger.shared.logTap(
                        objectType: .button,
                        label: "Back Button"
                    )
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .foregroundColor(.black)
                }
                // Back demoted so VoiceOver focuses main content first; back via three-finger swipe or later in order
                .accessibilityLabel("Back")
                .accessibilityHint("Return to dashboard")
                .accessibilitySortPriority(-1)
                .accessibilityScrollAction { edge in
                    // When VoiceOver focus is on back button, three-finger swipe right triggers this
                    if edge == .trailing {
                        speech.stop(immediate: true)
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            speech.stop(immediate: true)
        }
    }
    
    // MARK: - Navigation Buttons
    
    @ViewBuilder
    private func navigationButtons(scrollProxy: ScrollViewProxy) -> some View {
        HStack {
            Button {
                moveToPreviousPage(scrollProxy: scrollProxy)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Prev")
                }
                .font(.custom("Arial", size: 14).weight(.semibold))
                .foregroundColor(canGoPrevious ? ColorTokens.primary : ColorTokens.primary.opacity(0.4))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(canGoPrevious ? ColorTokens.primary : ColorTokens.primary.opacity(0.4), lineWidth: 1)
                )
            }
            .disabled(!canGoPrevious || isNavigating)
            .accessibilityLabel("Previous page")
            .accessibilityHint(canGoPrevious ? "Go to page \(safePageIndex)" : "Already on first page")

            Spacer()

            Button {
                moveToNextPage(scrollProxy: scrollProxy)
            } label: {
                HStack(spacing: 4) {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
                .font(.custom("Arial", size: 14).weight(.semibold))
                .foregroundColor(canGoNext ? .white : .white.opacity(0.6))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(canGoNext ? ColorTokens.primary : ColorTokens.primary.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(!canGoNext || isNavigating)
            .accessibilityLabel("Next page")
            .accessibilityHint(canGoNext ? "Go to page \(safePageIndex + 2)" : "Already on last page")
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.top, Spacing.large)
    }

    // MARK: - Page Navigation

    private func moveToNextPage(scrollProxy: ScrollViewProxy) {
        guard !isNavigating, canGoNext else { return }
        
        isNavigating = true
        haptics.pageChange()
        
        InteractionLogger.shared.log(
            event: .pageChange,
            objectType: .pageControl,
            label: "Next Page",
            location: .zero,
            additionalInfo: "From page \(safePageIndex + 1) to \(safePageIndex + 2)"
        )
        
        currentPage = safePageIndex + 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollProxy.scrollTo("topAnchor", anchor: .top)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isNavigating = false
            announcePageChange()
        }
    }

    private func moveToPreviousPage(scrollProxy: ScrollViewProxy) {
        guard !isNavigating, canGoPrevious else { return }
        
        isNavigating = true
        haptics.pageChange()
        
        InteractionLogger.shared.log(
            event: .pageChange,
            objectType: .pageControl,
            label: "Previous Page",
            location: .zero,
            additionalInfo: "From page \(safePageIndex + 1) to \(safePageIndex)"
        )
        
        currentPage = safePageIndex - 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollProxy.scrollTo("topAnchor", anchor: .top)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isNavigating = false
            announcePageChange()
        }
    }

    private func announcePageChange() {
        guard !pages.isEmpty else { return }
        haptics.sectionChange()
        
        if UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Page \(safePageIndex + 1) of \(pages.count)"
                )
            }
        }
    }

    // MARK: - Heading Skip Logic (prevents title duplication)
    
    private func shouldSkipHeading(_ node: Node) -> Bool {
        if case .heading(let level, let text) = node {
            // Skip question headings (e.g., "Question 1", "Q.", "Q ")
            if isQuestionHeading(text) {
                return true
            }
            // Skip if H1 heading matches the navigation title (avoid duplication)
            if level == 1 && text.trimmingCharacters(in: .whitespaces).lowercased() == title.trimmingCharacters(in: .whitespaces).lowercased() {
                return true
            }
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
    @EnvironmentObject var mathSpeech: MathSpeechService
    @EnvironmentObject var speech: SpeechService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var contentPadding: CGFloat {
        horizontalSizeClass == .regular ? Spacing.large : Spacing.medium
    }

    var body: some View {
        // Images render directly without card wrapper
        if case .image(let src, let alt, let shortDesc) = node {
            ImageBlockView(dataURI: src, alt: alt, shortDesc: shortDesc)
               
        } else {
            // Everything else gets the white card
            VStack(alignment: .leading, spacing: Spacing.small) {
                nodeContent
            }
            .padding(contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
            )
        }
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
                .onAppear {
                    InteractionLogger.shared.logVoiceOverFocus(
                        objectType: .heading,
                        label: text
                    )
                }

        case .paragraph(let items):
            ParagraphBlockView(items: items)
                .environmentObject(haptics)
                .environmentObject(mathSpeech)
                .environmentObject(speech)

        case .image(let src, let alt, let shortDesc):
            // This case won't be reached due to the if-else in body
            ImageBlockView(dataURI: src, alt: alt, shortDesc: shortDesc)

        case .svgNode(let svg, let title, let summaries, let shortDesc, let graphicData):
            SVGBlockView(svg: svg, title: title, summaries: summaries, shortDesc: shortDesc, graphicData: graphicData)
                .environmentObject(haptics)

        case .mapNode(let json, let title, let summaries):
            DocumentMapView(json: json, title: title, summaries: summaries)

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
    
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @EnvironmentObject var speech: SpeechService
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
                    .onAppear {
                        InteractionLogger.shared.logVoiceOverFocus(
                            objectType: .paragraph,
                            label: String(combinedText.prefix(50))
                        )
                    }
            }
            
            ForEach(mathParts, id: \.0) { _, mathInline in
                if case .math(let latex, let mathml, let display) = mathInline {
                    MathCATEquationView(latex: latex, mathml: mathml, display: display)
                        .environmentObject(haptics)
                        .environmentObject(mathSpeech)
                        .environmentObject(speech)
                }
            }
        }
    }
}

// MARK: - MathCAT Equation View

private struct MathCATEquationView: View {
    let latex: String?
    let mathml: String?
    let display: String?
    
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @EnvironmentObject var speech: SpeechService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var spokenString: String {
        mathSpeech.speakable(from: mathml, latex: latex, verbosity: .verbose)
    }
    
    private var mathParts: [MathPart] {
        MathParser.parse(mathml: mathml, latex: latex)
    }
    
    var body: some View {
        MathCATView(
            mathml: mathml,
            latex: latex,
            fullSpokenText: spokenString,
            mathParts: mathParts,
            displayType: display,
            onEnterMathMode: {
                haptics.mathStart()
                InteractionLogger.shared.log(
                    event: .mathModeEnter,
                    objectType: .mathEquation,
                    label: "Math Mode Entered",
                    location: .zero,
                    additionalInfo: latex ?? "equation"
                )
            },
            onExitMathMode: {
                haptics.mathEnd()
                InteractionLogger.shared.log(
                    event: .mathModeExit,
                    objectType: .mathEquation,
                    label: "Math Mode Exited",
                    location: .zero
                )
            }
        )
        .frame(height: 60)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ColorTokens.primaryLight3)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Image Block

private struct ImageBlockView: View {
    let dataURI: String
    let alt: String?
    let shortDesc: String?
    
    private var accessibilityDescription: String {
        // Use short_desc if available, otherwise fall back to alt
        if let shortDesc = shortDesc, !shortDesc.isEmpty {
            return shortDesc
        }
        return alt ?? "Image"
    }
    
    var body: some View {
        Group {
            if let img = loadImage() {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.clear)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Rectangle()
                    .fill(Color(hex: "#DEECF8"))
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityAddTraits(.isImage)
        .onAppear {
            InteractionLogger.shared.logVoiceOverFocus(
                objectType: .image,
                label: alt ?? "Image"
            )
        }
    }
    
    private func loadImage() -> UIImage? {
        var base64String = dataURI
        if let range = dataURI.range(of: "base64,") {
            base64String = String(dataURI[range.upperBound...])
        }
        guard let data = Data(base64Encoded: base64String) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - SVG Block

private struct SVGBlockView: View {
    let svg: String
    let title: String?
    let summaries: [String]?
    let shortDesc: [String]?
    let graphicData: [String: Any]?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @State private var showMultisensoryView = false
    @State private var svgElementID = UUID()
    
    private var svgHeight: CGFloat {
        horizontalSizeClass == .regular ? 300 : 200
    }
    
    private var accessibilityDescription: String {
        // Use short_desc if available, otherwise fall back to title + summaries
        if let shortDesc = shortDesc, !shortDesc.isEmpty {
            return shortDesc.joined(separator: ". ") + ". Double tap to explore with touch and haptics"
        }
        var description = title ?? "Graphic"
        if let summaries = summaries, !summaries.isEmpty {
            description += ". " + summaries.joined(separator: ". ")
        }
        description += ". Double tap to explore with touch and haptics"
        return description
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            if let t = title {
                Text(t)
                    .font(.custom("Arial", size: 17).weight(.bold))
                    .foregroundColor(Color(hex: "#121417"))
                    .accessibilityHidden(true)
            }

<<<<<<< HEAD
            SVGView(svg: svg)
=======
            if graphicData != nil {
                ZStack {
                    SVGView(svg: svg, graphicData: graphicData)
                        .frame(maxWidth: .infinity)
                        .frame(height: svgHeight)
                        .clipped()
                        .allowsHitTesting(false)
                    
                    // Transparent overlay to capture double tap
                    Rectangle()
                        .fill(Color.clear)
                        .frame(maxWidth: .infinity)
                        .frame(height: svgHeight)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            haptics.tapSelection()
                            showMultisensoryView = true
                        }
                }
            } else {
                // Show alt text if graphicData is missing
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text(accessibilityDescription)
                        .font(.custom("Arial", size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
>>>>>>> feature/map-style-svg-rendering
                .frame(maxWidth: .infinity)
                .frame(height: svgHeight)
                .background(Color(hex: "#F5F5F5"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
<<<<<<< HEAD
        .accessibilityAddTraits(.isImage)
        .onAppear {
            InteractionLogger.shared.logVoiceOverFocus(
                objectType: .svg,
                label: title ?? "Graphic"
            )
        }
=======
        .accessibilityHint("Double tap to explore this graphic with touch and haptic feedback")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("svg-element-\(svgElementID)")
        .fullScreenCover(isPresented: $showMultisensoryView, onDismiss: {
            // FIXED: Return VoiceOver focus to this SVG element after dismissing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIAccessibility.post(notification: .screenChanged, argument: nil)
            }
        }) {
            if let graphicData = graphicData {
                MultisensorySVGView(graphicData: graphicData, title: title)
                    .environmentObject(haptics)
                    .environmentObject(speech)
                    .onAppear {
                        #if DEBUG
                        print("🔵 MultisensorySVGView appeared")
                        if let lines = graphicData["lines"] as? [[String: Any]] {
                            print("  Lines: \(lines.count)")
                        }
                        if let vertices = graphicData["vertices"] as? [[String: Any]] {
                            print("  Vertices: \(vertices.count)")
                        }
                        #endif
                    }
            } else {
                Text("Graphic data not available")
                    .padding()
            }
        }
    }
}

// MARK: - SVG WebView

private struct SVGWebView: UIViewRepresentable {
    let svg: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        webView.scrollView.isAccessibilityElement = false
        webView.scrollView.accessibilityElementsHidden = true
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta name="viewport" content="initial-scale=1, maximum-scale=1, user-scalable=no"/>
            <style>
                * { -webkit-user-select: none; user-select: none; }
                body { margin: 0; padding: 0; background: #fff; }
                svg { max-width: 100%; height: auto; display: block; }
                [tabindex], a, button, input, [role] { pointer-events: none; }
            </style>
        </head>
        <body aria-hidden="true" role="presentation" tabindex="-1">
            <div aria-hidden="true" role="presentation">\(svg)</div>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        webView.scrollView.isAccessibilityElement = false
        webView.scrollView.accessibilityElementsHidden = true
>>>>>>> feature/map-style-svg-rendering
    }
}