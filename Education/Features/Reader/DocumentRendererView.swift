//
//  DocumentRendererView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import SwiftUI
import UIKit

/// Generic document reader - uses native VoiceOver rotor for reading
/// NO custom play buttons - follows Figma design
struct DocumentRendererView: View {
    let title: String
    let nodes: [Node]

    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var haptics: HapticService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "#F5F5F5")
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    // Title - centered per Figma
                    Text(title)
                        .font(.custom("Arial", size: 28))
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#121417"))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, Spacing.small)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityHeading(.h1)

                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                            DocumentNodeView(node: node)
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
        .navigationTitle("Worksheet")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            speech.stop(immediate: true)
        }
    }
}

// MARK: - Document Node View

private struct DocumentNodeView: View {
    let node: Node
    
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

        case .image(let src, let alt):
            DocumentImageView(dataURI: src, alt: alt)

        case .svgNode(let svg, let t, let d):
            DocumentSVGView(svg: svg, title: t, summaries: d)

        case .unknown:
            EmptyView()
        }
    }
}

// MARK: - Document Paragraph (VoiceOver rotor enabled)

private struct DocumentParagraphView: View {
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
            let combinedText = textParts.joined()
            if !combinedText.isEmpty {
                Text(combinedText)
                    .font(.custom("Arial", size: 17))
                    .foregroundColor(Color(hex: "#121417"))
                    // VoiceOver rotor works on this text
            }
            
            ForEach(mathParts, id: \.0) { _, mathInline in
                if case .math(let latex, let mathml, let display) = mathInline {
                    DocumentMathPill(latex: latex, mathml: mathml, display: display)
                }
            }
        }
    }
}

// MARK: - Document Math Pill

private struct DocumentMathPill: View {
    let latex: String?
    let mathml: String?
    let display: String?
    
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @EnvironmentObject var speech: SpeechService
    
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
                    .font(.custom("Arial", size: 15))
                    .foregroundColor(Color(hex: "#121417"))
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.primaryLight3)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Equation")
        .accessibilityHint("Double tap to hear the equation")
        .onAppear {
            if UIAccessibility.isVoiceOverRunning {
                haptics.mathTerm()
            }
        }
    }
}

// MARK: - Document Image View

private struct DocumentImageView: View {
    let dataURI: String
    let alt: String?
    
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
                    .frame(height: 160)
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

// MARK: - Document SVG View

private struct DocumentSVGView: View {
    let svg: String
    let title: String?
    let summaries: [String]?
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            if let t = title {
                Text(t)
                    .font(.custom("Arial", size: 17).weight(.bold))
                    .foregroundColor(Color(hex: "#121417"))
            }

            SVGView(svg: svg)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
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
        }
    }
}

// MARK: - Accessible Image (shared)

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
                .accessibilityLabel(alt ?? "image")
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
                .accessibilityLabel(alt ?? "image")
        }
    }

    private func decode(dataURI: String) -> UIImage? {
        guard let range = dataURI.range(of: "base64,") else { return nil }
        let base64 = String(dataURI[range.upperBound...])
        guard let data = Data(base64Encoded: base64) else { return nil }
        return UIImage(data: data)
    }
}
