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
    @EnvironmentObject var mathSpeech: MathSpeechService
    @Environment(\.dismiss) private var dismiss

    @AccessibilityFocusState private var isBackButtonFocused: Bool

    // Filter out third SVG node (temporary fix)
    private var filteredNodes: [Node] {
        var svgCount = 0
        return nodes.compactMap { node in
            if case .svgNode = node {
                svgCount += 1
                if svgCount == 3 {
                    return nil // Skip third SVG
                }
            }
            return node
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "#F5F5F5")
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {

                    // Card container
                    VStack(alignment: .leading, spacing: Spacing.medium) {
                        ForEach(Array(filteredNodes.enumerated()), id: \.offset) { _, node in
                            DocumentNodeView(node: node)
                                .environmentObject(haptics)
                                .environmentObject(mathSpeech)
                                .environmentObject(speech)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.large)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.screenPadding)
                .padding(.top, Spacing.large)
                .padding(.bottom, Spacing.xLarge)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isBackButtonFocused = true
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
                .accessibilityFocused($isBackButtonFocused)
                .accessibilitySortPriority(1000)
            }
        }
        .accessibilityAction(.escape) {
            speech.stop(immediate: true)
            dismiss()
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

        case .image(let src, let alt):
            DocumentImageView(dataURI: src, alt: alt)
                .frame(maxWidth: .infinity, alignment: .leading)

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
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Document Image View

private struct DocumentImageView: View {
    let dataURI: String
    let alt: String?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var decodedImage: UIImage? = nil
    @State private var isLoading: Bool = true

    private var maxImageHeight: CGFloat {
        horizontalSizeClass == .regular ? 500 : 350
    }

    private var placeholderHeight: CGFloat { 160 }
    
    // Simple in-memory cache to prevent re-decoding
    private static var imageCache: [String: UIImage] = [:]
    private static let cacheQueue = DispatchQueue(label: "documentImageCache", attributes: .concurrent)

    var body: some View {
        GeometryReader { geometry in
            if let img = decodedImage {
                let aspectRatio = img.size.width / img.size.height
                let containerWidth = geometry.size.width
                let naturalHeight = containerWidth / aspectRatio
                let finalHeight = min(naturalHeight, maxImageHeight)
                let finalWidth = finalHeight * aspectRatio
                
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .frame(width: finalWidth, height: finalHeight)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(alt ?? "Image")
                    .accessibilityAddTraits(.isImage)
            } else {
                Rectangle()
                    .fill(Color(hex: "#DEECF8"))
                    .frame(maxWidth: .infinity)
                    .frame(height: isLoading ? placeholderHeight : placeholderHeight)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(alt ?? "Image")
                    .accessibilityAddTraits(.isImage)
            }
        }
        .frame(height: maxImageHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        // Check cache first
        DocumentImageView.cacheQueue.sync {
            if let cached = DocumentImageView.imageCache[dataURI] {
                DispatchQueue.main.async {
                    decodedImage = cached
                    isLoading = false
                }
                return
            }
        }
        
        // Decode on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            guard let range = dataURI.range(of: "base64,") else {
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            let base64 = String(dataURI[range.upperBound...])
            guard let data = Data(base64Encoded: base64),
                  let img = UIImage(data: data) else {
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            // Cache the decoded image
            DocumentImageView.cacheQueue.async(flags: .barrier) {
                DocumentImageView.imageCache[dataURI] = img
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                decodedImage = img
                isLoading = false
            }
        }
    }
}


// MARK: - Document SVG View

private struct DocumentSVGView: View {
    let svg: String
    let title: String?
    let summaries: [String]?
    
    @State private var parsedGraphic: ParsedGraphic? = nil
    @State private var isLoading: Bool = true

    private var accessibilityDescription: String {
        var description = title ?? "Graphic"
        if let summaries = summaries, !summaries.isEmpty {
            description += ". " + summaries.joined(separator: ". ")
        }
        return description
    }

    private var hasTactileElements: Bool {
        svg.contains("<line") || svg.contains("<circle") || svg.contains("<polygon") || svg.contains("<path")
    }
    
    private func loadParsedGraphic() {
        // Check cache first (fast, synchronous)
        let cacheKey = "\(title ?? "graphic")_\(svg.hashValue)"
        if let cachedData = UserDefaults.standard.data(forKey: "graphic_json_\(cacheKey)"),
           let cached = SVGToJSONConverter.loadFromJSON(data: cachedData) {
            #if DEBUG
            print("[JSONGraphic] ✅ Loaded from JSON cache: \(cacheKey)")
            #endif
            parsedGraphic = cached
            isLoading = false
            return
        }
        
        // Parse on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            #if DEBUG
            print("[JSONGraphic] 🔄 Converting SVG to JSON and caching...")
            #endif
            
            guard let jsonData = SVGToJSONConverter.convertToJSON(svgContent: svg) else {
                #if DEBUG
                print("[JSONGraphic] ❌ Failed to convert SVG to JSON")
                #endif
                DispatchQueue.main.async {
                    isLoading = false
                }
                return
            }
            
            UserDefaults.standard.set(jsonData, forKey: "graphic_json_\(cacheKey)")
            #if DEBUG
            print("[JSONGraphic] 💾 Cached JSON: \(cacheKey) (\(jsonData.count) bytes)")
            #endif
            
            let parsed = SVGToJSONConverter.loadFromJSON(data: jsonData)
            DispatchQueue.main.async {
                parsedGraphic = parsed
                isLoading = false
            }
        }
    }

    var body: some View {
        VStack(alignment: .center, spacing: Spacing.xSmall) {
            if let t = title {
                Text(t)
                    .font(.custom("Arial", size: 17).weight(.bold))
                    .foregroundColor(Color(hex: "#121417"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
            }

            if hasTactileElements {
                if let parsed = parsedGraphic {
                    let scene = TactileScene.from(parsed)
                    let aspectSize = CGSize(
                        width: max(1, scene.viewBox.width),
                        height: max(1, scene.viewBox.height)
                    )
                    GeometryReader { geometry in
                        let w = max(1, geometry.size.width)
                        let h = max(1, geometry.size.height)
                        TactileCanvasView(scene: scene, title: title, summaries: summaries)
                            .frame(width: w, height: h)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .aspectRatio(aspectSize.width / aspectSize.height, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 250)
                } else if isLoading {
                    // Show fallback while loading (prevents hang)
                    let scene = SVGToTactileParser.parse(svgContent: svg, viewSize: .zero)
                    let aspectSize = CGSize(
                        width: max(1, scene.viewBox.width),
                        height: max(1, scene.viewBox.height)
                    )
                    GeometryReader { geometry in
                        let w = max(1, geometry.size.width)
                        let h = max(1, geometry.size.height)
                        TactileCanvasView(scene: scene, title: title, summaries: summaries)
                            .frame(width: w, height: h)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .aspectRatio(aspectSize.width / aspectSize.height, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 250)
                } else {
                    // Fallback if parsing failed
                    let scene = SVGToTactileParser.parse(svgContent: svg, viewSize: .zero)
                    let aspectSize = CGSize(
                        width: max(1, scene.viewBox.width),
                        height: max(1, scene.viewBox.height)
                    )
                    GeometryReader { geometry in
                        let w = max(1, geometry.size.width)
                        let h = max(1, geometry.size.height)
                        TactileCanvasView(scene: scene, title: title, summaries: summaries)
                            .frame(width: w, height: h)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .aspectRatio(aspectSize.width / aspectSize.height, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 250)
                }
            } else {
                SVGKitView(svg: svg, contentMode: .scaleAspectFit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
            }
        }
        .onAppear {
            if parsedGraphic == nil && isLoading {
                loadParsedGraphic()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.medium)
        .modifier(DocumentSVGAccessibility(
            hasTactileElements: hasTactileElements,
            accessibilityDescription: accessibilityDescription
        ))
    }
}

private struct DocumentSVGAccessibility: ViewModifier {
    let hasTactileElements: Bool
    let accessibilityDescription: String

    func body(content: Content) -> some View {
        Group {
            if hasTactileElements {
                content
            } else {
                content
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(accessibilityDescription)
                    .accessibilityAddTraits(.isImage)
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
