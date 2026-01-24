//
//  MathAccessibilityElement.swift
//  Education
//
//  Behavior:
//  - On VoiceOver focus: Says "Math equation. Double tap to read."
//  - On double-tap: VoiceOver reads the full equation with pauses
//

import UIKit
import SwiftUI
import WebKit

// MARK: - MathPart (kept for compatibility)

struct MathPart {
    let text: String
    let level: MathNavigationLevel
    let children: [MathPart]
    
    init(text: String, level: MathNavigationLevel = .term, children: [MathPart] = []) {
        self.text = text
        self.level = level
        self.children = children
    }
}

enum MathNavigationLevel: String, CaseIterable {
    case character = "Character"
    case symbol = "Symbol"
    case term = "Term"
    case structure = "Structure"
    
    var next: MathNavigationLevel { self }
    var previous: MathNavigationLevel { self }
}

// MARK: - MathCAT Accessibility Container

class MathCATAccessibilityContainer: UIView {
    
    // The full equation spoken text (set by MathCATView)
    var fullEquationText: String = "equation" {
        didSet {
            // Debug: print when text is set
            print("MathCAT: fullEquationText set to: \(fullEquationText)")
        }
    }
    
    // Kept for compatibility
    var mathParts: [MathPart] = []
    
    // Haptic
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    // Callbacks
    var onEnterMathMode: (() -> Void)?
    var onExitMathMode: (() -> Void)?
    
    // Track state
    private var hasBeenActivated = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAccessibility()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAccessibility()
    }
    
    private func setupAccessibility() {
        isAccessibilityElement = true
        accessibilityTraits = [.button, .staticText]
        impactGenerator.prepare()
    }
    
    // MARK: - Accessibility Properties
    
    override var accessibilityLabel: String? {
        get { return "Math equation" }
        set { }
    }
    
    override var accessibilityHint: String? {
        get { return "Double tap to read" }
        set { }
    }
    
    override var accessibilityValue: String? {
        get { return nil }
        set { }
    }
    
    // MARK: - Double-tap Action
    
    override func accessibilityActivate() -> Bool {
        print("MathCAT: accessibilityActivate called")
        print("MathCAT: fullEquationText = '\(fullEquationText)'")
        
        // Haptic feedback
        impactGenerator.impactOccurred(intensity: 1.0)
        onEnterMathMode?()
        
        // Clean and prepare the text
        let textToRead = prepareTextForReading(fullEquationText)
        
        print("MathCAT: textToRead = '\(textToRead)'")
        
        guard !textToRead.isEmpty else {
            print("MathCAT: Text is empty, announcing 'Equation'")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UIAccessibility.post(notification: .announcement, argument: "Equation")
            }
            return true
        }
        
        // Announce with VoiceOver - use slight delay to let current speech finish
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            print("MathCAT: Announcing: '\(textToRead)'")
            UIAccessibility.post(notification: .announcement, argument: textToRead)
            
            // Call exit after a delay based on text length
            let readingTime = Double(textToRead.count) * 0.05 + 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + readingTime) {
                self?.onExitMathMode?()
            }
        }
        
        return true
    }
    
    // MARK: - Text Preparation
    
    private func prepareTextForReading(_ text: String) -> String {
        var cleaned = text
        
        // Remove prefixes
        let prefixes = ["Equation: ", "Equation:", "equation: ", "equation:", "Math: ", "Math:"]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }
        
        // Remove answer portions
        let answerPatterns = [
            #"[,.]?\s*(the\s+)?(sum|total|answer|result|area|volume|perimeter|value)\s+(is|are|=|equals)\s+[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?"#,
            #"\s+is\s+[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?$"#,
            #"\s*(=|equals)\s*[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?$"#,
            #"[,\.]\s*[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?$"#,
            #"\s*(which|that|this)\s+(is|are|equals)\s+[\d,\.]+.*$"#,
            #"\.\s+\d+\.?\d*\s*$"#
        ]
        
        for pattern in answerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }
        
        // Clean up formatting
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        cleaned = cleaned.replacingOccurrences(of: ", ,", with: ",")
        cleaned = cleaned.replacingOccurrences(of: ",,", with: ",")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove trailing punctuation
        while cleaned.hasSuffix(",") || cleaned.hasSuffix(";") {
            cleaned = String(cleaned.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        
        // If just "equation" or empty, return empty to trigger fallback
        if cleaned.lowercased() == "equation" || cleaned.isEmpty {
            return ""
        }
        
        return cleaned
    }
}

// MARK: - SwiftUI Wrapper

struct MathCATView: UIViewRepresentable {
    let mathml: String?
    let latex: String?
    let fullSpokenText: String
    let mathParts: [MathPart]
    let displayType: String?
    
    var onEnterMathMode: (() -> Void)?
    var onExitMathMode: (() -> Void)?
    
    func makeUIView(context: Context) -> MathCATAccessibilityContainer {
        let container = MathCATAccessibilityContainer()
        container.backgroundColor = .clear
        
        // Add WebView for visual rendering
        let webView = createMathWebView()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // Set initial values
        container.fullEquationText = fullSpokenText
        container.mathParts = mathParts
        container.onEnterMathMode = onEnterMathMode
        container.onExitMathMode = onExitMathMode
        
        return container
    }
    
    func updateUIView(_ container: MathCATAccessibilityContainer, context: Context) {
        // Update the spoken text
        container.fullEquationText = fullSpokenText
        container.mathParts = mathParts
        container.onEnterMathMode = onEnterMathMode
        container.onExitMathMode = onExitMathMode
        
        // Update WebView
        if let webView = container.subviews.first(where: { $0 is WKWebView }) as? WKWebView {
            loadMathContent(into: webView)
        }
    }
    
    private func createMathWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        
        // CRITICAL: Hide from VoiceOver - container handles accessibility
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        
        loadMathContent(into: webView)
        return webView
    }
    
    private func loadMathContent(into webView: WKWebView) {
        guard let mathml = mathml, !mathml.isEmpty else {
            let html = createFallbackHTML()
            webView.loadHTMLString(html, baseURL: nil)
            return
        }
        
        let cleanedMathML = cleanMathML(mathml)
        let isDisplay = displayType?.lowercased() == "block" || displayType?.lowercased() == "display"
        let mathStyle = isDisplay ? "display: block; margin: 12px 0;" : "display: inline-block;"
        
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { -webkit-user-select: none; user-select: none; pointer-events: none; }
                body { margin: 0; padding: 8px; background: transparent; font-family: -apple-system; }
                math { \(mathStyle) font-size: 18px; color: #121417; }
                @media (prefers-color-scheme: dark) { math { color: #FFFFFF; } }
            </style>
        </head>
        <body aria-hidden="true" role="presentation" inert>\(cleanedMathML)</body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private func createFallbackHTML() -> String {
        let displayText = latex ?? "Equation"
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { pointer-events: none; }
                body { margin: 8px; font-family: -apple-system; font-size: 16px; background: transparent; }
            </style>
        </head>
        <body aria-hidden="true" inert>\(displayText)</body>
        </html>
        """
    }
    
    private func cleanMathML(_ mathml: String) -> String {
        var cleaned = mathml.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !cleaned.hasPrefix("<math") {
            cleaned = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\(cleaned)</math>"
        }
        
        if !cleaned.contains("xmlns=") {
            cleaned = cleaned.replacingOccurrences(
                of: "<math",
                with: "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"",
                options: .caseInsensitive
            )
        }
        
        return cleaned
    }
}
