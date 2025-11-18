//
//  DocumentRendererView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import SwiftUI

/// Generic document reader (continuous view) –
/// used for non-worksheet content if needed.
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

                    if nodes.isEmpty {
                        // If something goes wrong with JSON we never crash – we show a
                        // simple explanation instead of a blank screen.
                        Text("This document does not contain any readable content yet.")
                            .font(Typography.body)
                            .foregroundColor(ColorTokens.textSecondaryAdaptive)
                            .padding(.top, Spacing.medium)
                    } else {
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
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.top, Spacing.large)
                .padding(.bottom, Spacing.xLarge)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        isPlaying.toggle()
                        if isPlaying {
                            haptics.tapSelection()
                            speech.speak(collectSpeakable(nodes: nodes))
                        } else {
                            speech.stop(immediate: true)
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
        .navigationTitle("Reader")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - TTS

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
                    case .math: return "[equation]"
                    default: return nil
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

// MARK: - Shared helpers (used by WorksheetView too)

/// Renders inline text + math inside a paragraph.
struct ParagraphRichText: View {
    let items: [Inline]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                switch item {
                case .text(let t):
                    Text(t)
                        .font(Typography.body)
                        .foregroundColor(ColorTokens.textPrimaryAdaptive)

                case .math(let latex, let mathml, _):
                    MathRunView(latex: latex, mathml: mathml)

                default:
                    EmptyView()
                }
            }
        }
    }
}

/// Image view that respects the *actual* aspect ratio of the decoded image,
/// so nothing gets cut off inside the card.
struct AccessibleImage: View {
    let dataURI: String
    let alt: String?

    var body: some View {
        if let img = decode(dataURI: dataURI) {
            // Use the *real* aspect ratio of the image
            Image(uiImage: img)
                .resizable()
                .aspectRatio(img.size, contentMode: .fit)   // key: use real aspect ratio
                .frame(maxWidth: .infinity, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))
                .accessibilityLabel(alt ?? "image")
        } else {
            // Placeholder if decode fails
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
