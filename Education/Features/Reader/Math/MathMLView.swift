//
//  MathMLView.swift
//  Education
//
//  Renders MathML equations using WKWebView (iOS native MathML support)
//  Accessibility is handled by MathCATAccessibilityContainer in MathCATView
//

import SwiftUI
import WebKit
import Foundation

struct MathMLView: UIViewRepresentable {
    let mathml: String
    let latex: String?
    let displayType: String? // "inline" or "block"
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.configuration.preferences.javaScriptEnabled = true
        
        // FIXED: WebView is ONLY for visual rendering
        // Accessibility is completely handled by parent MathCATAccessibilityContainer
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Clean and prepare MathML
        let cleanedMathML = cleanMathML(mathml)
        
        // Determine if it's display (block) or inline math
        let isDisplay = displayType?.lowercased() == "block" || displayType?.lowercased() == "display"
        let mathStyle = isDisplay ? "display: block; margin: 12px 0;" : "display: inline-block;"
        
        // Create HTML with proper MathML structure
        // aria-hidden="true" ensures screen readers completely ignore this
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * {
                    -webkit-user-select: none;
                    user-select: none;
                }
                body {
                    margin: 0;
                    padding: 8px;
                    background: transparent;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
                }
                math {
                    \(mathStyle)
                    font-size: 18px;
                    color: #121417;
                }
                @media (prefers-color-scheme: dark) {
                    math {
                        color: #FFFFFF;
                    }
                }
            </style>
        </head>
        <body aria-hidden="true" role="presentation">
            \(cleanedMathML)
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
        
        // FIXED: Ensure accessibility is COMPLETELY disabled
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        webView.scrollView.isAccessibilityElement = false
        webView.scrollView.accessibilityElementsHidden = true
    }
    
    private func cleanMathML(_ mathml: String) -> String {
        // Ensure MathML is properly formatted
        var cleaned = mathml.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it doesn't start with <math>, wrap it
        if !cleaned.hasPrefix("<math") {
            cleaned = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\(cleaned)</math>"
        }
        
        // Ensure namespace is present
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

// MARK: - Legacy Helper Methods (kept for compatibility)

extension MathMLView {
    /// Extract alttext from MathML for speech
    static func extractAltText(from mathml: String) -> String? {
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
    
    /// Convert alttext or LaTeX to natural speech (MathCAT-like)
    static func convertToSpeech(_ text: String) -> String {
        var speech = text
        
        // Handle fractions
        speech = speech.replacingOccurrences(of: "\\frac{", with: "fraction ")
        speech = speech.replacingOccurrences(of: "}{", with: " over ")
        
        // Handle binomials
        speech = speech.replacingOccurrences(of: "\\binom{", with: "binomial coefficient ")
        
        // Handle common operations
        speech = speech.replacingOccurrences(of: "\\sum", with: "sum")
        speech = speech.replacingOccurrences(of: "\\prod", with: "product")
        speech = speech.replacingOccurrences(of: "\\int", with: "integral")
        speech = speech.replacingOccurrences(of: "\\lim", with: "limit")
        
        // Handle trigonometric functions
        speech = speech.replacingOccurrences(of: "\\sin", with: "sine")
        speech = speech.replacingOccurrences(of: "\\cos", with: "cosine")
        speech = speech.replacingOccurrences(of: "\\tan", with: "tangent")
        
        // Handle logarithms
        speech = speech.replacingOccurrences(of: "\\log", with: "log")
        speech = speech.replacingOccurrences(of: "\\ln", with: "natural log")
        
        // Handle exponents and subscripts
        speech = speech.replacingOccurrences(of: "^{", with: " to the power of ")
        speech = speech.replacingOccurrences(of: "^", with: " to the power of ")
        speech = speech.replacingOccurrences(of: "_{", with: " sub ")
        speech = speech.replacingOccurrences(of: "_", with: " sub ")
        
        // Handle operators
        speech = speech.replacingOccurrences(of: "\\cdot", with: " times ")
        speech = speech.replacingOccurrences(of: "\\times", with: " times ")
        speech = speech.replacingOccurrences(of: "\\div", with: " divided by ")
        speech = speech.replacingOccurrences(of: "=", with: " equals ")
        speech = speech.replacingOccurrences(of: "+", with: " plus ")
        speech = speech.replacingOccurrences(of: "-", with: " minus ")
        
        // Handle comparisons
        speech = speech.replacingOccurrences(of: "\\leq", with: " less than or equal to ")
        speech = speech.replacingOccurrences(of: "\\geq", with: " greater than or equal to ")
        speech = speech.replacingOccurrences(of: "\\neq", with: " not equal to ")
        speech = speech.replacingOccurrences(of: "\\approx", with: " approximately equal to ")
        speech = speech.replacingOccurrences(of: "<", with: " less than ")
        speech = speech.replacingOccurrences(of: ">", with: " greater than ")
        
        // Handle Greek letters
        speech = speech.replacingOccurrences(of: "\\pi", with: "pi")
        speech = speech.replacingOccurrences(of: "\\theta", with: "theta")
        speech = speech.replacingOccurrences(of: "\\alpha", with: "alpha")
        speech = speech.replacingOccurrences(of: "\\beta", with: "beta")
        speech = speech.replacingOccurrences(of: "\\gamma", with: "gamma")
        speech = speech.replacingOccurrences(of: "\\delta", with: "delta")
        speech = speech.replacingOccurrences(of: "\\Delta", with: "delta")
        speech = speech.replacingOccurrences(of: "\\sigma", with: "sigma")
        speech = speech.replacingOccurrences(of: "\\Sigma", with: "sigma")
        
        // Handle special symbols
        speech = speech.replacingOccurrences(of: "\\infty", with: "infinity")
        speech = speech.replacingOccurrences(of: "\\pm", with: "plus or minus")
        speech = speech.replacingOccurrences(of: "\\sqrt{", with: "square root of ")
        speech = speech.replacingOccurrences(of: "\\sqrt", with: "square root")
        
        // Handle parentheses for clarity
        speech = speech.replacingOccurrences(of: "(", with: " open parenthesis ")
        speech = speech.replacingOccurrences(of: ")", with: " close parenthesis ")
        speech = speech.replacingOccurrences(of: "[", with: " open bracket ")
        speech = speech.replacingOccurrences(of: "]", with: " close bracket ")
        
        // Clean up LaTeX artifacts
        speech = speech.replacingOccurrences(of: "\\", with: "")
        speech = speech.replacingOccurrences(of: "{", with: "")
        speech = speech.replacingOccurrences(of: "}", with: "")
        
        // Clean up multiple spaces
        speech = speech.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        speech = speech.trimmingCharacters(in: .whitespaces)
        
        return speech
    }
}

// MARK: - MathRunView (Legacy - kept for compatibility but uses MathCAT now)

struct MathRunView: View {
    let latex: String?
    let mathml: String?
    @EnvironmentObject var haptics: HapticService
    @EnvironmentObject var mathSpeech: MathSpeechService
    @EnvironmentObject var speech: SpeechService

    var body: some View {
        // This now wraps MathCATView for consistent behavior
        let spokenText = mathSpeech.speakable(from: mathml, latex: latex, verbosity: .verbose)
        let parts = MathParser.parse(mathml: mathml, latex: latex)
        
        MathCATView(
            mathml: mathml,
            latex: latex,
            fullSpokenText: spokenText,
            mathParts: parts,
            displayType: nil,
            onEnterMathMode: {
                haptics.mathStart()
            },
            onExitMathMode: {
                haptics.mathEnd()
            }
        )
        .frame(height: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
