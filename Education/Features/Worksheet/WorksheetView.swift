//
//  WorksheetView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/13/25.
//

import SwiftUI

/// Worksheet-style reader used for JSON worksheets (all three samples).
/// - Each JSON file = one "page".
/// - Inside a page, every Node (heading / paragraph / image / equation / svg)
///   becomes its own white card block, so VoiceOver moves block-by-block.
struct WorksheetView: View {
    let title: String
    /// Outer index = page index (0-based), inner array = all WorksheetItems on that page.
    /// Each WorksheetItem just groups the raw `Node` list for that page.
    let pages: [[WorksheetItem]]

    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService

    /// Current page index (0-based)
    @State private var currentPage: Int = 0
    /// Global TTS state for "play entire page"
    @State private var isPlayingPage = false

    // Convenience: safe current page index even if pages is empty.
    private var safePageIndex: Int {
        guard !pages.isEmpty else { return 0 }
        return min(max(currentPage, 0), pages.count - 1)
    }

    /// All items on the currently selected page.
    private var currentItems: [WorksheetItem] {
        guard pages.indices.contains(safePageIndex) else { return [] }
        return pages[safePageIndex]
    }

    var body: some View {
        ZStack {
            ColorTokens.backgroundAdaptive
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {

                    // Big worksheet title at the top
                    Text(title)
                        .font(Typography.heading1)
                        .foregroundColor(ColorTokens.textPrimaryAdaptive)
                        .padding(.top, Spacing.large)
                        .accessibilityAddTraits(.isHeader)

                    // Page indicator ("Page 1 of 2")
                    if !pages.isEmpty {
                        Text("Page \(safePageIndex + 1) of \(pages.count)")
                            .font(Typography.caption1)
                            .foregroundColor(ColorTokens.textSecondaryAdaptive)
                            .padding(.bottom, Spacing.small)
                    }

                    // MAIN CONTENT: every node on this page as a separate block
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        ForEach(currentItems) { item in
                            ForEach(Array(item.nodes.enumerated()), id: \.offset) { _, node in
                                if !shouldSkipQuestionHeading(node) {    // don't show "Question 1" heading
                                    NodeBlockView(node: node)
                                }
                            }
                        }
                    }

                    // Page navigation buttons – no horizontal swipe.
                    if pages.count > 1 {
                        HStack {
                            Button {
                                moveToPreviousPage()
                            } label: {
                                Text("Previous page")
                                    .font(Typography.body)
                            }
                            .disabled(safePageIndex == 0)
                            .opacity(safePageIndex == 0 ? 0.4 : 1.0)
                            .accessibilityHint("Moves to the previous worksheet page.")

                            Spacer()

                            Button {
                                moveToNextPage()
                            } label: {
                                Text(safePageIndex == pages.count - 1 ? "Last page" : "Next page")
                                    .font(Typography.bodyBold)
                            }
                            .disabled(safePageIndex == pages.count - 1)
                            .opacity(safePageIndex == pages.count - 1 ? 0.4 : 1.0)
                            .accessibilityHint("Moves to the next worksheet page.")
                        }
                        .padding(.top, Spacing.large)
                    }
                }
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.bottom, Spacing.xLarge)
            }
        }
        .onAppear {
            announcePageChange()
        }
        .onChange(of: currentPage) { _ in
            stopPageReading(immediate: true)
            announcePageChange()
        }
        // Global toolbar: play / pause / stop for the current page
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    Button {
                        togglePageReading()
                    } label: {
                        Image(systemName: isPlayingPage ? "pause.fill" : "play.fill")
                    }
                    .accessibilityLabel(isPlayingPage ? "Pause reading" : "Play page")
                    .accessibilityHint("Double tap to start or pause reading this worksheet page.")

                    Button {
                        stopPageReading(immediate: true)
                    } label: {
                        Image(systemName: "stop.fill")
                    }
                    .accessibilityLabel("Stop reading")
                    .accessibilityHint("Stops reading and resets to the start of the page.")
                }
            }
        }
        .toolbarBackground(ColorTokens.backgroundAdaptive, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle("Worksheet")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Page navigation helpers

    private func moveToNextPage() {
        guard safePageIndex + 1 < pages.count else { return }
        haptics.tapSelection()
        currentPage = safePageIndex + 1
    }

    private func moveToPreviousPage() {
        guard safePageIndex > 0 else { return }
        haptics.tapSelection()
        currentPage = safePageIndex - 1
    }

    /// Page-change cue for blind users: gentle success haptic.
    private func announcePageChange() {
        guard !pages.isEmpty else { return }
        haptics.success()
    }

    // MARK: - Page-level TTS

    /// Toggle between play and pause for the current page.
    private func togglePageReading() {
        if isPlayingPage {
            // Pause / stop current speech
            stopPageReading(immediate: false)
        } else {
            // Start reading the whole page from the beginning
            let text = collectSpeakableForCurrentPage()
            guard !text.isEmpty else { return }
            isPlayingPage = true
            haptics.tapSelection()
            speech.speak(text)
        }
    }

    /// Hard-stop reading and reset the state.
    private func stopPageReading(immediate: Bool) {
        speech.stop(immediate: immediate)
        isPlayingPage = false
    }

    /// Combine all nodes on the current page into one speakable string.
    private func collectSpeakableForCurrentPage() -> String {
        var parts: [String] = []
        if !pages.isEmpty {
            parts.append("\(title). Page \(safePageIndex + 1) of \(pages.count).")
        }

        for item in currentItems {
            for node in item.nodes {
                switch node {
                case .heading(_, let t):
                    // Skip "Question 1" etc. but keep real headings.
                    if !isQuestionHeading(t) {
                        parts.append(t)
                    }

                case .paragraph(let inlines):
                    let text = inlines.compactMap { inline -> String? in
                        switch inline {
                        case .text(let t): return t
                        case .math:       return "[equation]"
                        default:          return nil
                        }
                    }.joined()
                    if !text.isEmpty { parts.append(text) }

                case .image(_, let alt):
                    parts.append(alt ?? "image")

                case .svgNode(_, let title, let summaries):
                    if let t = title { parts.append(t) }
                    if let first = summaries?.first { parts.append(first) }

                case .unknown:
                    break
                }
            }
        }

        return parts.joined(separator: ". ")
    }

    // MARK: - Heading helpers (skip "Question 1" inside page)

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

// MARK: - One visual block per JSON node

private struct NodeBlockView: View {
    let node: Node

    var body: some View {
        Group {
            switch node {
            case .heading(let level, let text):
                Text(text)
                    .font(
                        level == 1 ? Typography.heading2 :
                        level == 2 ? Typography.heading3 :
                        Typography.bodyBold
                    )
                    .foregroundColor(ColorTokens.textPrimaryAdaptive)

            case .paragraph(let items):
                HStack(alignment: .top, spacing: 0) {
                    ParagraphRichText(items: items)
                    Spacer(minLength: 0)
                }

            case .image(let src, let alt):
                AccessibleImage(dataURI: src, alt: alt)

            case .svgNode(let svg, let title, let summaries):
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    if let t = title {
                        Text(t)
                            .font(Typography.bodyBold)
                            .foregroundColor(ColorTokens.textPrimaryAdaptive)
                    }

                    SVGView(svg: svg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.small)

                    if let desc = summaries?.first {
                        Text(desc)
                            .font(Typography.footnote)
                            .foregroundColor(ColorTokens.textSecondaryAdaptive)
                    }
                }
                .accessibilityLabel((title ?? "Graphic") + ". " + (summaries?.first ?? ""))

            case .unknown:
                EmptyView()
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.surfaceAdaptive)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .contain)
    }
}
