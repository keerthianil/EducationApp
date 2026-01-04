//
//  MathSpeechService.swift
//  Education
//
//  Created by Keerthi Reddy on 10/28/25.
//

import Foundation
import Combine

final class MathSpeechService: ObservableObject {
    enum Verbosity { case brief, verbose }

    /// Converts MathML or LaTeX to speakable text for VoiceOver
    /// Prioritizes MathML alttext, then MathML parsing, then LaTeX
    func speakable(from mathml: String?, latex: String?, verbosity: Verbosity) -> String {
        // Try MathML first (better for accessibility)
        if let mathml = mathml, !mathml.isEmpty {
            // First, check for alttext attribute - this is the most accurate
            if let alttext = extractAltText(from: mathml), !alttext.isEmpty {
                // Clean up the alttext (it might have LaTeX notation)
                let cleaned = cleanAltText(alttext)
                return verbosity == .verbose ? "Equation: \(cleaned)" : cleaned
            }
            // If no alttext, parse the MathML structure
            return speakableFromMathML(mathml, verbosity: verbosity)
        }
        
        // Fall back to LaTeX
        if let latex = latex, !latex.isEmpty {
            return speakableFromLaTeX(latex, verbosity: verbosity)
        }
        
        return "equation"
    }
    
    private func cleanAltText(_ alttext: String) -> String {
        // The alttext might contain LaTeX notation, convert it to natural speech
        var cleaned = alttext
        
        // Handle fractions and binomials first (before other replacements)
        cleaned = cleaned.replacingOccurrences(of: "\\binom{", with: "binomial coefficient ")
        cleaned = cleaned.replacingOccurrences(of: "\\frac{", with: "fraction ")
        cleaned = cleaned.replacingOccurrences(of: "}{", with: " over ")
        
        // Handle sums and other operators
        cleaned = cleaned.replacingOccurrences(of: "\\sum", with: "sum")
        cleaned = cleaned.replacingOccurrences(of: "\\prod", with: "product")
        cleaned = cleaned.replacingOccurrences(of: "\\int", with: "integral")
        
        // Handle superscripts and subscripts
        cleaned = cleaned.replacingOccurrences(of: "^{", with: " to the power of ")
        cleaned = cleaned.replacingOccurrences(of: "_", with: " sub ")
        
        // Handle operators
        cleaned = cleaned.replacingOccurrences(of: "=", with: " equals ")
        cleaned = cleaned.replacingOccurrences(of: "+", with: " plus ")
        cleaned = cleaned.replacingOccurrences(of: "-", with: " minus ")
        cleaned = cleaned.replacingOccurrences(of: "*", with: " times ")
        cleaned = cleaned.replacingOccurrences(of: "\\cdot", with: " times ")
        cleaned = cleaned.replacingOccurrences(of: "\\times", with: " times ")
        
        // Handle parentheses and brackets
        cleaned = cleaned.replacingOccurrences(of: "(", with: "open parenthesis ")
        cleaned = cleaned.replacingOccurrences(of: ")", with: " close parenthesis ")
        cleaned = cleaned.replacingOccurrences(of: "[", with: "open bracket ")
        cleaned = cleaned.replacingOccurrences(of: "]", with: " close bracket ")
        
        // Remove LaTeX backslashes and braces
        cleaned = cleaned.replacingOccurrences(of: "\\", with: "")
        cleaned = cleaned.replacingOccurrences(of: "{", with: "")
        cleaned = cleaned.replacingOccurrences(of: "}", with: "")
        
        // Clean up extra spaces and normalize
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        
        return cleaned
    }
    
    /// Legacy method for backward compatibility
    func speakable(from latex: String, verbosity: Verbosity) -> String {
        return speakableFromLaTeX(latex, verbosity: verbosity)
    }
    
    // MARK: - MathML Parsing
    
    private func speakableFromMathML(_ mathml: String, verbosity: Verbosity) -> String {
        // Extract alttext if available (best case - already human-readable)
        if let alttext = extractAltText(from: mathml) {
            let result = cleanMathMLText(alttext)
            return verbosity == .verbose ? "Equation: \(result)" : result
        }
        
        // Extract text content from MathML elements
        var result = extractTextFromMathML(mathml)
        result = cleanMathMLText(result)
        
        if result.isEmpty {
            // Fallback: try to extract from LaTeX if present in attributes
            if let latex = extractLaTeXFromMathML(mathml) {
                return speakableFromLaTeX(latex, verbosity: verbosity)
            }
            return "equation"
        }
        
        return verbosity == .verbose ? "Equation: \(result)" : result
    }
    
    private func extractAltText(from mathml: String) -> String? {
        // Look for alttext attribute in math tag
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
    
    private func extractTextFromMathML(_ mathml: String) -> String {
        var result = ""
        
        // Extract text from <mi> (identifier), <mn> (number), <mo> (operator), <mtext> (text)
        let patterns = [
            ("<mi[^>]*>([^<]+)</mi>", "identifier"),
            ("<mn[^>]*>([^<]+)</mn>", "number"),
            ("<mtext[^>]*>([^<]+)</mtext>", "text"),
            ("<mo[^>]*>([^<]+)</mo>", "operator")
        ]
        
        for (pattern, _) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(mathml.startIndex..., in: mathml)
                let matches = regex.matches(in: mathml, options: [], range: range)
                for match in matches {
                    if match.numberOfRanges > 1,
                       let textRange = Range(match.range(at: 1), in: mathml) {
                        let text = String(mathml[textRange])
                        if !result.isEmpty && !result.hasSuffix(" ") {
                            result += " "
                        }
                        result += text
                    }
                }
            }
        }
        
        // Handle special operators and symbols
        result = result.replacingOccurrences(of: "∑", with: "sum")
        result = result.replacingOccurrences(of: "∏", with: "product")
        result = result.replacingOccurrences(of: "∫", with: "integral")
        result = result.replacingOccurrences(of: "=", with: "equals")
        result = result.replacingOccurrences(of: "+", with: "plus")
        result = result.replacingOccurrences(of: "−", with: "minus")
        result = result.replacingOccurrences(of: "×", with: "times")
        result = result.replacingOccurrences(of: "÷", with: "divided by")
        result = result.replacingOccurrences(of: "(", with: "open parenthesis")
        result = result.replacingOccurrences(of: ")", with: "close parenthesis")
        result = result.replacingOccurrences(of: "[", with: "open bracket")
        result = result.replacingOccurrences(of: "]", with: "close bracket")
        result = result.replacingOccurrences(of: "{", with: "open brace")
        result = result.replacingOccurrences(of: "}", with: "close brace")
        result = result.replacingOccurrences(of: "<", with: "less than")
        result = result.replacingOccurrences(of: ">", with: "greater than")
        result = result.replacingOccurrences(of: "≤", with: "less than or equal to")
        result = result.replacingOccurrences(of: "≥", with: "greater than or equal to")
        result = result.replacingOccurrences(of: "≠", with: "not equal to")
        result = result.replacingOccurrences(of: "≈", with: "approximately equal to")
        result = result.replacingOccurrences(of: "±", with: "plus or minus")
        result = result.replacingOccurrences(of: "∞", with: "infinity")
        result = result.replacingOccurrences(of: "√", with: "square root")
        result = result.replacingOccurrences(of: "π", with: "pi")
        result = result.replacingOccurrences(of: "α", with: "alpha")
        result = result.replacingOccurrences(of: "β", with: "beta")
        result = result.replacingOccurrences(of: "γ", with: "gamma")
        result = result.replacingOccurrences(of: "θ", with: "theta")
        result = result.replacingOccurrences(of: "Δ", with: "delta")
        result = result.replacingOccurrences(of: "Σ", with: "sigma")
        
        // Handle superscripts and subscripts context
        result = result.replacingOccurrences(of: "^", with: " to the power of ")
        result = result.replacingOccurrences(of: "_", with: " sub ")
        
        // Clean up extra spaces
        result = result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespaces)
        
        return result
    }
    
    private func extractLaTeXFromMathML(_ mathml: String) -> String? {
        // Some MathML might have LaTeX in data attributes
        let pattern = #"data-latex=["']([^"']+)["']"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(mathml.startIndex..., in: mathml)
            if let match = regex.firstMatch(in: mathml, options: [], range: range) {
                if let latexRange = Range(match.range(at: 1), in: mathml) {
                    return String(mathml[latexRange])
                }
            }
        }
        return nil
    }
    
    private func cleanMathMLText(_ text: String) -> String {
        var cleaned = text
        // Remove extra whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - LaTeX Parsing
    
    private func speakableFromLaTeX(_ latex: String, verbosity: Verbosity) -> String {
        var t = latex
        
        // Remove LaTeX commands and convert to speech
        t = t.replacingOccurrences(of: "\\frac{", with: "fraction ")
        t = t.replacingOccurrences(of: "}{", with: " over ")
        t = t.replacingOccurrences(of: "\\binom{", with: "binomial coefficient ")
        t = t.replacingOccurrences(of: "\\sqrt{", with: "square root of ")
        t = t.replacingOccurrences(of: "\\sqrt[", with: "root of ")
        t = t.replacingOccurrences(of: "^", with: " to the power of ")
        t = t.replacingOccurrences(of: "_", with: " sub ")
        t = t.replacingOccurrences(of: "\\cdot", with: " times ")
        t = t.replacingOccurrences(of: "\\times", with: " times ")
        t = t.replacingOccurrences(of: "\\div", with: " divided by ")
        t = t.replacingOccurrences(of: "\\sum", with: "sum ")
        t = t.replacingOccurrences(of: "\\prod", with: "product ")
        t = t.replacingOccurrences(of: "\\int", with: "integral ")
        t = t.replacingOccurrences(of: "\\lim", with: "limit ")
        t = t.replacingOccurrences(of: "\\sin", with: "sine ")
        t = t.replacingOccurrences(of: "\\cos", with: "cosine ")
        t = t.replacingOccurrences(of: "\\tan", with: "tangent ")
        t = t.replacingOccurrences(of: "\\log", with: "log ")
        t = t.replacingOccurrences(of: "\\ln", with: "natural log ")
        t = t.replacingOccurrences(of: "\\exp", with: "exponential ")
        t = t.replacingOccurrences(of: "\\pi", with: "pi")
        t = t.replacingOccurrences(of: "\\theta", with: "theta")
        t = t.replacingOccurrences(of: "\\alpha", with: "alpha")
        t = t.replacingOccurrences(of: "\\beta", with: "beta")
        t = t.replacingOccurrences(of: "\\gamma", with: "gamma")
        t = t.replacingOccurrences(of: "\\Delta", with: "delta")
        t = t.replacingOccurrences(of: "\\infty", with: "infinity")
        t = t.replacingOccurrences(of: "\\leq", with: "less than or equal to")
        t = t.replacingOccurrences(of: "\\geq", with: "greater than or equal to")
        t = t.replacingOccurrences(of: "\\neq", with: "not equal to")
        t = t.replacingOccurrences(of: "\\approx", with: "approximately equal to")
        t = t.replacingOccurrences(of: "\\pm", with: "plus or minus")
        t = t.replacingOccurrences(of: "\\mp", with: "minus or plus")
        
        // Handle operators
        t = t.replacingOccurrences(of: "=", with: " equals ")
        t = t.replacingOccurrences(of: "+", with: " plus ")
        t = t.replacingOccurrences(of: "-", with: " minus ")
        
        // Handle parentheses
        t = t.replacingOccurrences(of: "(", with: "open parenthesis ")
        t = t.replacingOccurrences(of: ")", with: " close parenthesis ")
        
        // Clean up braces and brackets
        t = t.replacingOccurrences(of: "{", with: "")
        t = t.replacingOccurrences(of: "}", with: "")
        t = t.replacingOccurrences(of: "[", with: "")
        t = t.replacingOccurrences(of: "]", with: "")
        t = t.replacingOccurrences(of: "\\", with: "")
        
        // Clean up extra spaces
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespaces)

        switch verbosity {
        case .brief:   return t
        case .verbose: return "Equation: \(t)"
        }
    }
}
