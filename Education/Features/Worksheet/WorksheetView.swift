//
//  WorksheetView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/13/25.
//

import SwiftUI

struct WorksheetView: View {
    let title: String
    /// pages[pageIndex] = array of items on that page
    let pages: [[WorksheetItem]]

    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var speech: SpeechService

    @State private var searchText: String = ""
    @State private var currentPage: Int = 0        // swipe left / right between JSON pages

    // Filter items **within one page**
    private func filteredItems(on pageIndex: Int) -> [WorksheetItem] {
        guard pages.indices.contains(pageIndex) else { return [] }
        let items = pages[pageIndex]

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }

        return items.filter { $0.matches(search: trimmed) }
    }

    var body: some View {
        ZStack {
            ColorTokens.backgroundAdaptive.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Spacing.large) {
                // Title at top – big header in Figma
                Text(title)
                    .font(Typography.heading1)
                    .foregroundColor(ColorTokens.textPrimaryAdaptive)
                    .padding(.top, Spacing.large)

                // Search + Filter row (top bar in Figma)
                HStack(spacing: Spacing.small) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(ColorTokens.textSecondaryAdaptive)
                        TextField("Search…", text: $searchText)
                            .textInputAutocapitalization(.sentences)
                    }
                    .padding(.horizontal, Spacing.medium)
                    .frame(height: 44)
                    .background(ColorTokens.surfaceAdaptive)
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge))

                    Button {
                        haptics.tapSelection()
                        // TODO: hook real filters if needed
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("Filter")
                                .font(Typography.subheadline)
                        }
                        .padding(.horizontal, Spacing.medium)
                        .frame(height: 44)
                        .background(ColorTokens.surfaceAdaptive)
                        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge))
                    }
                    .accessibilityLabel("Filter questions")
                }

                // Page indicator – JSON page based
                if !pages.isEmpty {
                    Text("Page \(currentPage + 1) of \(pages.count)")
                        .font(Typography.caption1)
                        .foregroundColor(ColorTokens.textSecondaryAdaptive)
                        .padding(.bottom, Spacing.small)
                }

                // MAIN CONTENT: swipe left / right to change **page**
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { pageIndex in
                        ScrollView {
                            VStack(alignment: .leading, spacing: Spacing.medium) {
                                ForEach(filteredItems(on: pageIndex)) { item in
                                    WorksheetQuestionCard(item: item)
                                }
                            }
                            .padding(.horizontal, Spacing.screenPadding)
                            .padding(.vertical, Spacing.medium)
                        }
                        .tag(pageIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            .padding(.horizontal, Spacing.screenPadding)
            .padding(.bottom, Spacing.large)
        }
        .navigationTitle("Worksheet")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Question card (one logical block on the page)

struct WorksheetQuestionCard: View {
    let item: WorksheetItem

    /// Skip headings like "Question 1" – the card should start with page content.
    private var contentNodes: [Node] {
        item.nodes.filter { node in
            if case .heading(_, let text) = node {
                let lower = text.lowercased()
                if lower.hasPrefix("question ") ||
                    lower.hasPrefix("q.") ||
                    lower.hasPrefix("q ") {
                    return false
                }
            }
            return true
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: Spacing.medium) {
                // All sections on the page (the red boxes you drew)
                ForEach(Array(contentNodes.enumerated()), id: \.offset) { _, node in
                    QuestionNodeView(node: node)
                }
            }
            .padding(Spacing.large)
            .background(ColorTokens.surfaceAdaptive)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            .accessibilityElement(children: .contain)

            // Bookmark icon only – NO "Question 1" text
            Button {
                // Bookmark stub
            } label: {
                Image(systemName: "bookmark")
                    .foregroundColor(ColorTokens.primary)
                    .padding(Spacing.small)
            }
            .accessibilityLabel("Bookmark")
        }
    }
}

// MARK: - Node rendering inside a question card
/// Each Node in JSON is an **object** – heading, paragraph, image, svg, etc.

private struct QuestionNodeView: View {
    let node: Node

    var body: some View {
        switch node {
        case .heading(let level, let text):
            Text(text)
                .font(
                    level == 1 ? Typography.heading2 :
                    level == 2 ? Typography.heading3 :
                    Typography.bodyBold
                )
                .foregroundColor(ColorTokens.textPrimaryAdaptive)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .paragraph(let items):
            // Each paragraph / line is its own block – like your red boxes
            HStack(alignment: .top, spacing: 0) {
                ParagraphRichText(items: items)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(ColorTokens.surfaceAdaptive2)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall))

        case .image(let src, let alt):
            AccessibleImage(dataURI: src, alt: alt)
                .padding(.top, Spacing.small)

        case .svgNode(let svg, let t, let d):
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                if let tt = t {
                    Text(tt)
                        .font(Typography.bodyBold)
                        .foregroundColor(ColorTokens.textPrimaryAdaptive)
                }

                SVGView(svg: svg)
                    .frame(maxWidth: .infinity)

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
}
