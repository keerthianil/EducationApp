//
//  DocumentRendererView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//
//

import Foundation
import SwiftUI
import UIKit
import WebKit

struct DocumentRendererView: View {
    let title: String
    let nodes: [Node]

    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        documentContent
            .onThreeFingerSwipeBack {
                speech.stop(immediate: true)
                dismiss()
            }
    }
    
    private var documentContent: some View {
        ZStack {
            Color(hex: "#F5F5F5")
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                            DocumentNodeView(node: node)
                                .environmentObject(haptics)
                                .environmentObject(mathSpeech)
                                .environmentObject(speech)
                        }
                    }
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(title)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
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
                // Lower priority so VoiceOver focuses on main content first
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
}

// MARK: - Document Node View

private struct DocumentNodeView: View {
    let node: Node
    
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @EnvironmentObject var speech: SpeechService
    
    var body: some View {
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
            DocumentSVGView(svg: svg, title: t, summaries: d, shortDesc: shortDesc, graphicData: graphicData)
                .environmentObject(haptics)

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
            let combinedText = textParts.joined()
            if !combinedText.isEmpty {
                Text(combinedText)
                    .font(.custom("Arial", size: 17))
                    .foregroundColor(Color(hex: "#121417"))
            }
            
            ForEach(mathParts, id: \.0) { _, mathInline in
                if case .math(let latex, let mathml, let display) = mathInline {
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
            onEnterMathMode: {
                haptics.mathStart()
            },
            onExitMathMode: {
                haptics.mathEnd()
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

// MARK: - Document Image View

private struct DocumentImageView: View {
    let dataURI: String
    let alt: String?
    let shortDesc: String?
    
    private var accessibilityDescription: String {
        // Use shortDesc if available, otherwise fall back to alt
        if let shortDesc = shortDesc, !shortDesc.isEmpty {
            return shortDesc
        }
        return alt ?? "Image"
    }
    
    var body: some View {
        Group {
            if let img = decodeImage(dataURI: dataURI) {
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
    
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService
    @State private var showMultisensoryView = false
    @State private var svgElementID = UUID()
    
    private var accessibilityDescription: String {
        // Use shortDesc if available, otherwise fall back to title + summaries
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

            if graphicData != nil {
                ZStack {
                    SVGView(svg: svg, graphicData: graphicData)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .allowsHitTesting(false)
                    
                    // Transparent overlay to capture double tap
                    Rectangle()
                        .fill(Color.clear)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
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
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color(hex: "#F5F5F5"))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to explore this graphic with touch and haptic feedback")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("svg-element-\(svgElementID)")
        .fullScreenCover(isPresented: $showMultisensoryView, onDismiss: {
            // FIXED: Return VoiceOver focus to content after dismissing
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

// MARK: - Accessible Image (Legacy Support)

struct AccessibleImage: View {
    let dataURI: String
    let alt: String?

    var body: some View {
        if let img = decode(dataURI: dataURI) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(img.size, contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(alt ?? "image")
                .accessibilityAddTraits(.isImage)
        } else {
            Rectangle()
                .fill(Color(hex: "#DEECF8"))
                .frame(height: 160)
                .overlay(
                    Text(alt ?? "image")
                        .font(.custom("Arial", size: 13))
                        .foregroundColor(Color(hex: "#121417"))
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(alt ?? "image")
                .accessibilityAddTraits(.isImage)
        }
    }

    private func decode(dataURI: String) -> UIImage? {
        guard let range = dataURI.range(of: "base64,") else { return nil }
        let base64 = String(dataURI[range.upperBound...])
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}