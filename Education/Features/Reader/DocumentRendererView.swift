//
//  DocumentRendererView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import SwiftUI
import UIKit
import WebKit

/// Holds node focus anchor views so we can post UIAccessibility.screenChanged to them.
private final class NodeAnchorStore {
    var views: [Int: UIView] = [:]
}

/// UIKit focus anchor: a small UIView that VoiceOver can focus. Use with UIAccessibility.post(.screenChanged, argument: view).
private struct FocusAnchorView: UIViewRepresentable {
    let label: String
    let onMake: (UIView) -> Void

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        v.isAccessibilityElement = true
        v.accessibilityLabel = label
        v.accessibilityTraits = .header
        onMake(v)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        uiView.accessibilityLabel = label
    }
}

struct DocumentRendererView: View {
    let title: String
    let nodes: [Node]

    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @Environment(\.dismiss) private var dismiss

    @AccessibilityFocusState private var focusedNodeIndex: Int?
    @State private var focusReturnIndex: Int?
    @State private var titleAnchorView: UIView?
    @State private var nodeAnchorStore = NodeAnchorStore()

    var body: some View {
        documentContent
            .onThreeFingerSwipeBack {
                speech.stop(immediate: true)
                dismiss()
            }
            .onAppear {
                // Let anchor views be created, then force VO into scroll content (title → node 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if let titleView = titleAnchorView {
                        UIAccessibility.post(notification: .screenChanged, argument: titleView)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                        if let firstNodeView = nodeAnchorStore.views[0] {
                            UIAccessibility.post(notification: .screenChanged, argument: firstNodeView)
                        }
                    }
                }
            }
    }

    private var documentContent: some View {
        ZStack {
            Color(hex: "#F5F5F5")
                .ignoresSafeArea()
            documentScrollContent
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(title)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar { documentToolbar }
        .onDisappear {
            speech.stop(immediate: true)
        }
    }

    @ToolbarContentBuilder private var documentToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                speech.stop(immediate: true)
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
            }
            .accessibilityLabel("Back")
            .accessibilityHint("Return to dashboard")
            // Keep it low priority, but still accessible
            .accessibilitySortPriority(-10)
            .accessibilityScrollAction { edge in
                if edge == .trailing {
                    speech.stop(immediate: true)
                    dismiss()
                }
            }
        }
    }

    private var documentScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {

                // Invisible, focusable title anchor so VO doesn’t stick to the Back button
                FocusAnchorView(label: title) { titleAnchorView = $0 }
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: Spacing.medium) {
                    ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
                        DocumentNodeView(
                            node: node,
                            index: index,
                            focusReturnIndex: $focusReturnIndex,
                            nodeAnchorStore: nodeAnchorStore,
                            onDismissMultisensory: {
                                let idx = focusReturnIndex ?? 0
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    if let view = nodeAnchorStore.views[idx] {
                                        UIAccessibility.post(notification: .screenChanged, argument: view)
                                    }
                                }
                            }
                        )
                        .accessibilityFocused($focusedNodeIndex, equals: index)
                        .environmentObject(haptics)
                        .environmentObject(mathSpeech)
                        .environmentObject(speech)
                    }
                }
                .accessibilitySortPriority(10)
                .padding(Spacing.large)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.top, Spacing.large)
            .padding(.bottom, Spacing.xLarge)
        }
    }
}

// MARK: - Document Node View

private struct DocumentNodeView: View {
    let node: Node
    let index: Int
    @Binding var focusReturnIndex: Int?
    let nodeAnchorStore: NodeAnchorStore
    let onDismissMultisensory: () -> Void

    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @EnvironmentObject var speech: SpeechService

    private var nodeAnchorLabel: String {
        switch node {
        case .heading(_, let text): return text
        case .paragraph(let items):
            let parts = items.compactMap { if case .text(let t) = $0 { return t }; return nil }
            let s = parts.joined(separator: " ")
            return s.isEmpty ? "Paragraph" : String(s.prefix(80))
        case .image(_, let alt, _): return alt ?? "Image"
        case .svgNode(_, let t, _, _, _): return t ?? "Figure"
        case .mapNode(_, let t, _): return t ?? "Map"
        case .unknown: return "Content"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FocusAnchorView(label: nodeAnchorLabel) { nodeAnchorStore.views[index] = $0 }
                .frame(height: 1)
            nodeContent
        }
    }

    @ViewBuilder private var nodeContent: some View {
        switch node {
        case .heading(let level, let text):
            Text(text)
                .font(.custom("Arial", size: level == 1 ? 22 : level == 2 ? 20 : 18))
                .fontWeight(level <= 2 ? .bold : .semibold)
                .foregroundColor(Color(hex: "#121417"))
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(level == 1 ? .h1 : level == 2 ? .h2 : .h3)

        case .paragraph(let items):
            DocumentParagraphView(items: items)
                .environmentObject(haptics)
                .environmentObject(mathSpeech)
                .environmentObject(speech)

        case .image(let src, let alt, let shortDesc):
            DocumentImageView(dataURI: src, alt: alt, shortDesc: shortDesc)

        case .svgNode(let svg, let t, let d, let shortDesc, let graphicData):
            DocumentSVGView(
                svg: svg,
                title: t,
                summaries: d,
                shortDesc: shortDesc,
                graphicData: graphicData,
                nodeIndex: index,
                onOpenMultisensory: { focusReturnIndex = index },
                onDismissMultisensory: onDismissMultisensory
            )
            .environmentObject(haptics)
            .environmentObject(speech)

        case .mapNode(let json, let t, let d):
            DocumentMapView(json: json, title: t, summaries: d)

        case .unknown:
            EmptyView()
        }
    }
}

// MARK: - Document Paragraph
private struct DocumentParagraphView: View {
    let items: [Inline]

    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @EnvironmentObject var speech: SpeechService

    private enum Segment: Identifiable {
        case text(displayText: String, spokenText: String)
        case blockMath(latex: String?, mathml: String?, display: String?)
        var id: UUID { UUID() }
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        var displayBuffer = ""
        var spokenBuffer = ""
        
        func flushText() {
            let d = MathDisplayHelper.decodeHTMLEntities(displayBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
            let s = MathDisplayHelper.decodeHTMLEntities(spokenBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
            if !d.isEmpty {
                result.append(.text(displayText: d, spokenText: s.isEmpty ? d : s))
            }
            displayBuffer = ""
            spokenBuffer = ""
        }
        
        for inline in items {
            switch inline {
            case .text(let t):
                displayBuffer += t
                spokenBuffer += t
            case .math(let latex, let mathml, let display):
                let isBlock = display?.lowercased() == "block" || display?.lowercased() == "display"
                if isBlock {
                    flushText()
                    result.append(.blockMath(latex: latex, mathml: mathml, display: display))
                } else {
                    let displayStr = MathDisplayHelper.displayableText(mathml: mathml, latex: latex)
                    let spokenStr = mathSpeech.speakable(from: mathml, latex: latex, verbosity: .brief)
                    let cleanSpoken = spokenStr.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    displayBuffer += displayStr
                    spokenBuffer += cleanSpoken.isEmpty ? displayStr : cleanSpoken
                }
            case .unknown:
                break
            }
        }
        flushText()
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(segments) { segment in
                switch segment {
                case .text(let displayText, let spokenText):
                    Text(displayText)
                        .font(.custom("Arial", size: 17))
                        .foregroundColor(Color(hex: "#121417"))
                        .accessibilityLabel(spokenText)
                case .blockMath(let latex, let mathml, let display):
                    DocumentMathCATView(latex: latex, mathml: mathml, display: display)
                    .environmentObject(haptics)
                    .environmentObject(mathSpeech)
                    .environmentObject(speech)
                }
            }
        }
    }
}
// MARK: - Document MathCAT View

private struct DocumentMathCATView: View {
    let latex: String?
    let mathml: String?
    let display: String?

    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @EnvironmentObject var speech: SpeechService

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
            onEnterMathMode: { haptics.mathStart() },
            onExitMathMode: { haptics.mathEnd() }
        )
        .frame(minHeight: 80, maxHeight: 120)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ColorTokens.primaryLight3)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Document Image View

private struct DocumentImageView: View {
    let dataURI: String
    let alt: String?
    let shortDesc: String?

    private var accessibilityDescription: String {
        if let shortDesc = shortDesc, !shortDesc.isEmpty { return shortDesc }
        return alt ?? "Image"
    }

    var body: some View {
        Group {
            if let img = decodeImage(dataURI: dataURI) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
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
    }

    private func decodeImage(dataURI: String) -> UIImage? {
        guard let range = dataURI.range(of: "base64,") else { return nil }
        let base64 = String(dataURI[range.upperBound...])
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - Document SVG View

private struct DocumentSVGView: View {
    let svg: String
    let title: String?
    let summaries: [String]?
    let shortDesc: [String]?
    let graphicData: [String: Any]?
    let nodeIndex: Int
    let onOpenMultisensory: () -> Void
    let onDismissMultisensory: () -> Void

    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @State private var showMultisensoryView = false
    @State private var svgElementID = UUID()

    private var accessibilityDescription: String {
        if let shortDesc = shortDesc, !shortDesc.isEmpty {
            return shortDesc.joined(separator: ". ")
        }
        var description = title ?? "Graphic"
        if let summaries = summaries, !summaries.isEmpty {
            description += ". " + summaries.joined(separator: ". ")
        }
        return description
    }

    private func openMultisensory() {
        haptics.tapSelection()
        onOpenMultisensory()
        showMultisensoryView = true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            if let t = title {
                Text(t)
                    .font(.custom("Arial", size: 17).weight(.bold))
                    .foregroundColor(Color(hex: "#121417"))
                    .accessibilityHidden(true)
            }

            if graphicData != nil {
                // Use a real Button so VoiceOver double-tap reliably activates it.
                Button(action: openMultisensory) {
                    ZStack {
                        SVGView(svg: svg, graphicData: graphicData)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                        // Transparent overlay to ensure taps hit the Button,
                        // even if the underlying WKWebView behaves oddly.
                        Color.clear
                            .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .accessibilityLabel("\(accessibilityDescription).")
                .accessibilityHint("Double tap to explore with touch and haptics")
                .accessibilityAddTraits(.isButton)
                // Also support explicit VO activate action (belt + suspenders)
                .accessibilityAction(named: Text("Open")) {
                    openMultisensory()
                }


            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("\(accessibilityDescription). Double tap to explore with touch and haptics")
                        .font(.custom("Arial", size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color(hex: "#F5F5F5"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .accessibilityIdentifier("svg-element-\(svgElementID)")
        .fullScreenCover(isPresented: $showMultisensoryView, onDismiss: {
            onDismissMultisensory()
        }) {
            if let graphicData = graphicData {
                MultisensorySVGView(graphicData: graphicData, title: title)
                    .environmentObject(haptics)
                    .environmentObject(speech)
            } else {
                Text("Graphic data not available")
                    .padding()
            }
        }
    }
}
