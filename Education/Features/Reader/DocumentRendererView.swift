//
//  DocumentRendererView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import SwiftUI
import UIKit

/// Generic document reader (continuous view).
/// Used for non-worksheet content and for the current worksheet layout.
struct DocumentRendererView: View {
    let title: String
    let nodes: [Node]

    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var haptics: HapticService

    @State private var isPlaying = false

    var body: some View {
        ZStack {
            ColorTokens.backgroundAdaptive
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    Text(title)
                        .font(Typography.heading1)
                        .foregroundColor(ColorTokens.textPrimaryAdaptive)
                        .padding(.bottom, Spacing.small)
                        .accessibilityAddTraits(.isHeader)

                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                            rendered(node)
                        }
                    }
                    .padding(Spacing.large)
                    .background(ColorTokens.surfaceAdaptive)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge))
                    .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.top, Spacing.large)
                .padding(.bottom, Spacing.xLarge)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    // The parent NavigationStack handles the actual pop.
                    // We just make sure speech is stopped.
                    isPlaying = false
                    speech.stop(immediate: true)
                }
                .accessibilityLabel("Close worksheet")
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        // Toggle continuous read-aloud.
                        isPlaying.toggle()
                        if isPlaying {
                            haptics.tapSelection()
                            speech.speak(collectSpeakable(nodes: nodes))
                        } else {
                            speech.stop(immediate: false)
                        }
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    }
                    .accessibilityLabel(isPlaying ? "Pause reading" : "Play reading")

                    Button {
                        isPlaying = false
                        speech.stop(immediate: true)
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .accessibilityLabel("Stop reading")
                }
            }
        }
        .toolbarBackground(ColorTokens.backgroundAdaptive, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle("Worksheet")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Very important for blind users:
            // if we leave this screen (back button, Close, or app close),
            // the continuous loop must stop.
            isPlaying = false
            speech.stop(immediate: true)
        }
    }

    // MARK: - Node → View

    @ViewBuilder
    private func rendered(_ node: Node) -> some View {
        switch node {
        case .heading(let level, let text):
            Text(text)
                .font(
                    level == 1 ? Typography.heading1 :
                    level == 2 ? Typography.heading2 :
                    Typography.heading3
                )
                .foregroundColor(ColorTokens.textPrimaryAdaptive)
                .accessibilityAddTraits(.isHeader)

        case .paragraph(let items):
            HStack(alignment: .top, spacing: 0) {
                ParagraphRichText(items: items)
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

        case .image(let src, let alt):
            AccessibleImage(dataURI: src, alt: alt)

        case .svgNode(let svg, let t, let d):
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                if let tt = t {
                    Text(tt)
                        .font(Typography.bodyBold)
                        .foregroundColor(ColorTokens.textPrimaryAdaptive)
                }

                SVGView(svg: svg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.small)

                if let desc = d?.first {
                    Text(desc)
                        .font(Typography.footnote)
                        .foregroundColor(ColorTokens.textSecondaryAdaptive)
                }
            }
            .accessibilityLabel((t ?? "Graphic") + ". " + (d?.first ?? ""))

        case .unknown:
            EmptyView()
        }
    }

    // MARK: - TTS text builder

    private func collectSpeakable(nodes: [Node]) -> String {
        var out: [String] = [title]
        for n in nodes {
            switch n {
            case .heading(_, let t):
                out.append(t)
            case .paragraph(let items):
                let s = items.compactMap { inline -> String? in
                    switch inline {
                    case .text(let t): return t
                    case .math:        return "[equation]"
                    default:           return nil
                    }
                }.joined()
                out.append(s)
            case .image(_, let alt):
                out.append(alt ?? "image")
            case .svgNode(_, let t, let d):
                out.append(t ?? "graphic")
                if let d = d?.first { out.append(d) }
            default:
                break
            }
        }
        return out.joined(separator: ". ")
    }
}

// MARK: - Paragraph rich text + grouped math

/// Renders a paragraph as a sequence of text chunks and
/// grouped math objects. Any consecutive math inlines are
/// combined into ONE visual "math pill" so the equation
/// feels like a single object (not several little buttons).
struct ParagraphRichText: View {
    let items: [Inline]

    private enum Run {
        case text([Inline])
        case math([Inline])
    }

    /// Group contiguous math inlines together, and group
    /// contiguous non-math inlines together.
    private var runs: [Run] {
        var result: [Run] = []
        var currentText: [Inline] = []
        var currentMath: [Inline] = []

        func flushText() {
            if !currentText.isEmpty {
                result.append(.text(currentText))
                currentText.removeAll()
            }
        }

        func flushMath() {
            if !currentMath.isEmpty {
                result.append(.math(currentMath))
                currentMath.removeAll()
            }
        }

        for item in items {
            switch item {
            case .math:
                // Start / continue a math run
                flushText()
                currentMath.append(item)

            default:
                // Start / continue a text run
                flushMath()
                currentText.append(item)
            }
        }

        flushText()
        flushMath()
        return result
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
                switch run {
                case .text(let inlines):
                    // Merge all text in this run into a single Text view
                    let text = inlines.compactMap { inline -> String? in
                        if case .text(let t) = inline { return t }
                        return nil
                    }.joined()

                    if !text.isEmpty {
                        Text(text)
                            .font(Typography.body)
                            .foregroundColor(ColorTokens.textPrimaryAdaptive)
                    }

                case .math(let mathInlines):
                    GroupedMathRunView(parts: mathInlines)
                }
            }
        }
    }
}

/// One *logical* math object, possibly built from several
/// JSON math inlines. This is what appears as the blue "pill"
///  - shows the math (using LaTeX / text) visually,
///  - speaks a combined description when activated,
///  - avoids *overlapping* with VoiceOver by using
///    UIAccessibility announcements when VO is running.
private struct GroupedMathRunView: View {
    let parts: [Inline]

    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @EnvironmentObject var speech: SpeechService

    /// Combine LaTeX + nearby text for *visual* display.
    private var displayText: String {
        let pieces = parts.compactMap { inline -> String? in
            switch inline {
            case .math(let latex, _, _):
                return latex
            case .text(let t):
                // Sometimes "f(x)" is plain text adjacent to math.
                return t
            default:
                return nil
            }
        }
        let joined = pieces.joined(separator: " ")
        return joined.isEmpty ? "Equation" : joined
    }

    /// Combine LaTeX/MathML for speech.
    private var spokenString: String {
        let latexPieces = parts.compactMap { inline -> String? in
            if case .math(let latex, _, _) = inline { return latex }
            return nil
        }

        let mathmlPieces = parts.compactMap { inline -> String? in
            if case .math(_, let mathml, _) = inline { return mathml }
            return nil
        }

        if let latex = latexPieces.joined(separator: " ").nilIfEmpty {
            return mathSpeech.speakable(from: latex, verbosity: .brief)
        }
        if let mathml = mathmlPieces.joined(separator: " ").nilIfEmpty {
            return mathSpeech.speakable(from: mathml, verbosity: .brief)
        }
        return "equation"
    }

    var body: some View {
        Button {
            haptics.mathStart()

            let toSpeak = spokenString

            if UIAccessibility.isVoiceOverRunning {
                // Use VoiceOver's own channel – this queues nicely
                // after VO has spoken "Equation, button", so there’s
                // no overlapping / dual audio.
                UIAccessibility.post(notification: .announcement, argument: toSpeak)
            } else {
                // Non-VO case: use our shared speech engine.
                speech.speak(toSpeak)
            }

            haptics.mathEnd()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "function")
                Text(displayText)
                    .font(Typography.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(8)
            .background(ColorTokens.primaryLight3)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        // Keep this short so VO announces "Equation, button".
        .accessibilityLabel("Equation")
        .accessibilityHint("Double tap to hear math read aloud.")
    }
}

// Small helper to treat empty strings as nil.
private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// MARK: - Image helper

struct AccessibleImage: View {
    let dataURI: String
    let alt: String?

    var body: some View {
        if let img = decode(dataURI: dataURI) {
            Image(uiImage: img)
                .resizable()
                .aspectRatio(img.size, contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
                .accessibilityLabel(alt ?? "image")
        } else {
            Rectangle()
                .fill(ColorTokens.surfaceAdaptive2)
                .frame(height: 160)
                .overlay(
                    Text(alt ?? "image")
                        .font(Typography.caption1)
                        .foregroundColor(ColorTokens.textPrimaryAdaptive)
                )
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
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
