//
//  MathMLView.swift
//  Education
//
//  Renders MathML equations using WKWebView (iOS native MathML support)
//  Provides proper visual rendering and VoiceOver accessibility
//

import SwiftUI
import WebKit
import Foundation

struct MathMLView: UIViewRepresentable {
    let mathml: String
    let latex: String?
    let displayType: String? // "inline" or "block"
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.configuration.preferences.javaScriptEnabled = true
        
        // Configure for accessibility - let VoiceOver read MathML natively
        // Don't set accessibilityTraits or label - let the MathML content speak for itself
        webView.isAccessibilityElement = true
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Clean and prepare MathML
        let cleanedMathML = cleanMathML(mathml)
        
        // Determine if it's display (block) or inline math
        let isDisplay = displayType?.lowercased() == "block" || displayType?.lowercased() == "display"
        let mathStyle = isDisplay ? "display: block; margin: 12px 0;" : "display: inline-block;"
        
        // Create HTML with proper MathML structure and accessibility
        // VoiceOver reads MathML natively when properly formatted
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
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
        <body role="application" aria-label="Math equation">
            \(cleanedMathML)
        </body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
        
        // For VoiceOver: Use cleaned alttext if available, otherwise let it read MathML natively
        // iOS VoiceOver can read MathML, but cleaned alttext is often more accurate for speech
        if let alttext = extractAltText(from: mathml), !alttext.isEmpty {
            // Clean the alttext (it may contain LaTeX notation) for better speech
            let cleaned = cleanAltTextForSpeech(alttext)
            webView.accessibilityLabel = cleaned.isEmpty ? alttext : cleaned
        }
        // If no alttext, VoiceOver will read the MathML natively
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
    
    private func extractAltText(from mathml: String) -> String? {
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
    
    private func cleanAltTextForSpeech(_ alttext: String) -> String {
        // Convert LaTeX notation in alttext to natural speech
        var cleaned = alttext
        
        // Handle fractions and binomials
        cleaned = cleaned.replacingOccurrences(of: "\\binom{", with: "binomial coefficient ")
        cleaned = cleaned.replacingOccurrences(of: "\\frac{", with: "fraction ")
        cleaned = cleaned.replacingOccurrences(of: "}{", with: " over ")
        
        // Handle operators
        cleaned = cleaned.replacingOccurrences(of: "\\sum", with: "sum")
        cleaned = cleaned.replacingOccurrences(of: "=", with: " equals ")
        cleaned = cleaned.replacingOccurrences(of: "+", with: " plus ")
        cleaned = cleaned.replacingOccurrences(of: "-", with: " minus ")
        cleaned = cleaned.replacingOccurrences(of: "\\cdot", with: " times ")
        cleaned = cleaned.replacingOccurrences(of: "\\times", with: " times ")
        
        // Handle superscripts and subscripts
        cleaned = cleaned.replacingOccurrences(of: "^{", with: " to the power of ")
        cleaned = cleaned.replacingOccurrences(of: "_", with: " sub ")
        
        // Handle parentheses
        cleaned = cleaned.replacingOccurrences(of: "(", with: "open parenthesis ")
        cleaned = cleaned.replacingOccurrences(of: ")", with: " close parenthesis ")
        
        // Remove LaTeX syntax
        cleaned = cleaned.replacingOccurrences(of: "\\", with: "")
        cleaned = cleaned.replacingOccurrences(of: "{", with: "")
        cleaned = cleaned.replacingOccurrences(of: "}", with: "")
        
        // Clean up spaces
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        
        return cleaned
    }
}

