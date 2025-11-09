//
//  DocumentRendererView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import SwiftUI

struct DocumentRendererView: View {
    let title: String
    let nodes: [Node]

    @EnvironmentObject var speech: SpeechService
    @EnvironmentObject var haptics: HapticService

    @State private var isPlaying = false

    var body: some View {
        ZStack {
            ColorTokens.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.medium) {
                    Text(title)
                        .font(Typography.heading1)
                        .padding(.vertical, Spacing.small)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                        switch node {
                        case .heading(let level, let text):
                            Text(text)
                                .font(level == 1 ? Typography.heading1 :
                                      level == 2 ? Typography.heading2 : Typography.heading3)
                                .foregroundColor(ColorTokens.textPrimary)
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
                                if let tt = t { Text(tt).font(Typography.bodyBold) }
                                SVGView(svg: svg)
                                    .frame(height: 220)
                                if let desc = d?.first {
                                    Text(desc).font(Typography.footnote).foregroundColor(ColorTokens.textSecondary)
                                }
                            }
                            .accessibilityLabel((t ?? "Graphic") + ". " + (d?.first ?? ""))

                        case .unknown:
                            EmptyView()
                        }
                    }
                }
                .padding(Spacing.screenPadding)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        isPlaying.toggle()
                        if isPlaying {
                            haptics.tapSelection()
                            if UIAccessibility.isVoiceOverRunning {
                                UIAccessibility.post(notification: .announcement, argument: "Reading started")
                            } else {
                                speech.speak(collectSpeakable(nodes: nodes))
                            }
                        } else {
                            if UIAccessibility.isVoiceOverRunning {
                                UIAccessibility.post(notification: .announcement, argument: "Reading stopped")
                            } else {
                                speech.stop(immediate: true)
                            }
                        }
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    }
                    .accessibilityLabel(isPlaying ? "Pause reading" : "Play reading")

                    // Optional explicit stop button (separate from pause)
                    Button {
                        isPlaying = false
                        if UIAccessibility.isVoiceOverRunning {
                            UIAccessibility.post(notification: .announcement, argument: "Reading stopped")
                        } else {
                            speech.stop(immediate: true)
                        }
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .accessibilityLabel("Stop reading")
                }
            }
        }
        .navigationTitle("Reader")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func collectSpeakable(nodes: [Node]) -> String {
        var out: [String] = [title]
        for n in nodes {
            switch n {
            case .heading(_, let t): out.append(t)
            case .paragraph(let items):
                let s = items.compactMap { if case .text(let t) = $0 { return t } else { return "[equation]" } }.joined()
                out.append(s)
            case .image(_, let alt): out.append(alt ?? "image")
            case .svgNode(_, let t, let d):
                out.append(t ?? "graphic")
                if let d = d?.first { out.append(d) }
            default: break
            }
        }
        return out.joined(separator: ". ")
    }
}

// MARK: - paragraph rich text

private struct ParagraphRichText: View {
    let items: [Inline]
    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                switch item {
                case .text(let t): Text(t).font(Typography.body)
                case .math(let latex, let mathml, _):
                    MathRunView(latex: latex, mathml: mathml)
                default: EmptyView()
                }
            }
        }
    }
}

// MARK: - image from data URI

private struct AccessibleImage: View {
    let dataURI: String
    let alt: String?

    var body: some View {
        if let img = decode(dataURI: dataURI) {
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
                .accessibilityLabel(alt ?? "image")
                .accessibilityHint("Swipe right to continue.")
        } else {
            Rectangle()
                .fill(ColorTokens.surface2)
                .frame(height: 160)
                .overlay(Text(alt ?? "image").font(Typography.caption1))
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
