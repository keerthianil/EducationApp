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
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(title)
        .toolbarBackground(.visible, for: .navigationBar)
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

// MARK: - Document Paragraph

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
    
    private var spokenString: String {
        mathSpeech.speakable(from: mathml, latex: latex, verbosity: .verbose)
    }
    
    private var displayText: String {
        if let latex = latex, !latex.isEmpty {
            var display = latex
            display = display.replacingOccurrences(of: "\\", with: "")
            display = display.replacingOccurrences(of: "{", with: "")
            display = display.replacingOccurrences(of: "}", with: "")
            if display.count > 60 {
                return String(display.prefix(57)) + "..."
            }
            return display
        }
        if let mathml = mathml, !mathml.isEmpty {
            if let alttext = extractAltTextFromMathML(mathml) {
                return alttext
            }
            return "Math Equation"
        }
        return "Equation"
    }
    
    private func extractAltTextFromMathML(_ mathml: String) -> String? {
        let pattern = #"alttext=["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(mathml.startIndex..., in: mathml)
            if let match = regex.firstMatch(in: mathml, options: [], range: range) {
                if let altRange = Range(match.range(at: 1), in: mathml) {
                    return String(mathml[altRange])
                }
            }
        }
        return nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let mathml = mathml, !mathml.isEmpty {
                MathMLView(mathml: mathml, latex: latex, displayType: display)
                    .frame(height: 60)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.primaryLight3)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .accessibilityHint("Math equation. Double tap to explore equation elements in detail")
                    .onAppear {
                        if UIAccessibility.isVoiceOverRunning {
                            haptics.mathTerm()
                        }
                    }
            } else if let latex = latex, !latex.isEmpty {
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenString)
                .accessibilityHint("Double tap to hear the equation read aloud again")
                .accessibilityAddTraits(.startsMediaSession)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "function")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(ColorTokens.primary)
                    Text("Equation")
                        .font(.custom("Arial", size: 15))
                        .foregroundColor(Color(hex: "#121417"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.primaryLight3)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel("Math equation")
            }
        }
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
                .accessibilityLabel(summaries?.first ?? title ?? "Graphic")
        }
    }
}

// MARK: - Accessible Image

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
