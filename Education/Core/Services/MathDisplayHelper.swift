//
//  MathDisplayHelper.swift
//  Education
//
//  Converts LaTeX or MathML alttext into displayable Unicode text
//  for visual rendering in paragraphs. NOT for VoiceOver — that uses MathSpeechService.
//
//  Example: "\frac{a}{b}" → "a/b", "x^2" → "x²", "\pi" → "π"
//

import Foundation

enum MathDisplayHelper {

    /// Return a human-readable, visually clean string for inline math.
    /// Priority: alttext from MathML → cleaned LaTeX → raw LaTeX.
    static func displayableText(mathml: String?, latex: String?) -> String {
        // 1. Try alttext / aria-label from MathML
        if let mathml = mathml, !mathml.isEmpty {
            if let alt = extractAttribute(from: mathml, name: "alttext"), !alt.isEmpty {
                return cleanForDisplay(alt)
            }
            if let aria = extractAttribute(from: mathml, name: "aria-label"), !aria.isEmpty {
                return cleanForDisplay(aria)
            }
        }

        // 2. Clean LaTeX for display
        if let latex = latex, !latex.isEmpty {
            return latexToDisplay(latex)
        }

        return "equation"
    }

    // MARK: - Private

    private static func extractAttribute(from mathml: String, name: String) -> String? {
        let pattern = "\(name)=[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)),
              let range = Range(match.range(at: 1), in: mathml) else { return nil }
        return String(mathml[range])
    }

    /// Convert LaTeX to a readable display string using Unicode symbols.
    private static func latexToDisplay(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fractions: \frac{a}{b} → (a)/(b)  or  a/b for simple ones
        let fracPattern = #"\\frac\s*\{([^}]*)\}\s*\{([^}]*)\}"#
        if let regex = try? NSRegularExpression(pattern: fracPattern) {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "($1)/($2)")
        }

        // Square root: \sqrt{x} → √(x)
        let sqrtPattern = #"\\sqrt\s*\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: sqrtPattern) {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "√($1)")
        }

        // Superscripts with braces: x^{2} → x²  (common cases)
        let supBracePattern = #"\^\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: supBracePattern) {
            var result = s
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: result),
                   let expRange = Range(match.range(at: 1), in: result) {
                    let exp = String(result[expRange])
                    let sup = unicodeSuperscript(exp)
                    result.replaceSubrange(fullRange, with: sup)
                }
            }
            s = result
        }

        // Simple superscripts: ^2 → ², ^3 → ³
        s = s.replacingOccurrences(of: "^2", with: "²")
        s = s.replacingOccurrences(of: "^3", with: "³")

        // Subscripts with braces: _{n} → ₙ (best effort)
        let subBracePattern = #"_\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: subBracePattern) {
            var result = s
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: result),
                   let subRange = Range(match.range(at: 1), in: result) {
                    let sub = String(result[subRange])
                    let subText = unicodeSubscript(sub)
                    result.replaceSubrange(fullRange, with: subText)
                }
            }
            s = result
        }

        // Delimiter commands
        s = s.replacingOccurrences(of: "\\left(", with: "(")
        s = s.replacingOccurrences(of: "\\right)", with: ")")
        s = s.replacingOccurrences(of: "\\left[", with: "[")
        s = s.replacingOccurrences(of: "\\right]", with: "]")
        s = s.replacingOccurrences(of: "\\left\\{", with: "{")
        s = s.replacingOccurrences(of: "\\right\\}", with: "}")
        s = s.replacingOccurrences(of: "\\left|", with: "|")
        s = s.replacingOccurrences(of: "\\right|", with: "|")
        s = s.replacingOccurrences(of: "\\left", with: "")
        s = s.replacingOccurrences(of: "\\right", with: "")

        // Operators & symbols → Unicode
        let replacements: [(String, String)] = [
            ("\\times", "×"), ("\\cdot", "·"), ("\\div", "÷"),
            ("\\pm", "±"), ("\\mp", "∓"),
            ("\\leq", "≤"), ("\\geq", "≥"), ("\\neq", "≠"), ("\\approx", "≈"),
            ("\\infty", "∞"), ("\\pi", "π"), ("\\theta", "θ"),
            ("\\alpha", "α"), ("\\beta", "β"), ("\\gamma", "γ"),
            ("\\delta", "δ"), ("\\Delta", "Δ"), ("\\sigma", "σ"),
            ("\\Sigma", "Σ"), ("\\lambda", "λ"), ("\\omega", "ω"),
            ("\\Omega", "Ω"), ("\\phi", "φ"), ("\\epsilon", "ε"),
            ("\\sin", "sin"), ("\\cos", "cos"), ("\\tan", "tan"),
            ("\\log", "log"), ("\\ln", "ln"), ("\\lim", "lim"),
            ("\\sum", "Σ"), ("\\prod", "Π"), ("\\int", "∫"),
            ("\\to", "→"), ("\\rightarrow", "→"), ("\\leftarrow", "←"),
            ("\\Rightarrow", "⇒"), ("\\Leftarrow", "⇐"),
            ("\\quad", " "), ("\\qquad", "  "), ("\\,", " "),
            ("\\;", " "), ("\\!", ""), ("\\text", ""),
        ]

        for (cmd, uni) in replacements {
            s = s.replacingOccurrences(of: cmd, with: uni)
        }

        // Clean remaining backslashes & braces
        s = s.replacingOccurrences(of: "\\", with: "")
        s = s.replacingOccurrences(of: "{", with: "")
        s = s.replacingOccurrences(of: "}", with: "")

        // Collapse whitespace
        s = s.replacingOccurrences(of: "  ", with: " ")
        s = s.trimmingCharacters(in: .whitespaces)

        return s
    }

    /// Clean alttext for display (decode HTML entities, minor formatting)
    static func cleanForDisplay(_ text: String) -> String {
        var s = text
        s = decodeHTMLEntities(s)
        // Remove trailing/leading whitespace
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return s
    }

    /// Decode common HTML entities
    static func decodeHTMLEntities(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&lt;", with: "<")
        s = s.replacingOccurrences(of: "&gt;", with: ">")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        s = s.replacingOccurrences(of: "&apos;", with: "'")
        s = s.replacingOccurrences(of: "&#x2212;", with: "−")
        s = s.replacingOccurrences(of: "&#x2013;", with: "–")
        s = s.replacingOccurrences(of: "&#x2014;", with: "—")
        s = s.replacingOccurrences(of: "&#x00D7;", with: "×")
        // Numeric entities
        let numericPattern = #"&#(\d+);"#
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            var result = s
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: result),
                   let numRange = Range(match.range(at: 1), in: result),
                   let code = UInt32(result[numRange]),
                   let scalar = Unicode.Scalar(code) {
                    result.replaceSubrange(fullRange, with: String(scalar))
                }
            }
            s = result
        }
        return s
    }

    // MARK: - Unicode Super/Subscript

    private static func unicodeSuperscript(_ text: String) -> String {
        let map: [Character: String] = [
            "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
            "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
            "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
            "n": "ⁿ", "i": "ⁱ",
        ]
        let converted = text.map { map[$0] ?? String($0) }.joined()
        // If we couldn't convert everything, fall back to ^(text)
        let allConverted = text.allSatisfy { map[$0] != nil }
        return allConverted ? converted : "^(\(text))"
    }

    private static func unicodeSubscript(_ text: String) -> String {
        let map: [Character: String] = [
            "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
            "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
            "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
            "a": "ₐ", "e": "ₑ", "i": "ᵢ", "n": "ₙ", "o": "ₒ",
            "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ", "x": "ₓ",
        ]
        let converted = text.map { map[$0] ?? String($0) }.joined()
        let allConverted = text.allSatisfy { map[$0] != nil }
        return allConverted ? converted : "_(\(text))"
    }
}
