//
//  MathSpeechService.swift
//  Education
//
//  MATHCAT-LIKE: Full conversion of complex math to speech
//  Handles subscripts, superscripts, fractions, integrals, summations,
//  Greek letters, matrices, roots, binomials, and more.
//

import Foundation
import Combine

final class MathSpeechService: ObservableObject {
    
    enum Verbosity { case brief, verbose }
    
    // MARK: - Public API
    
    /// Convert math to spoken text with pauses for slow reading
    func speakable(from mathml: String?, latex: String?, verbosity: Verbosity) -> String {
        var result = convertToSpeech(mathml: mathml, latex: latex)
        
        // Clean answer portions
        result = cleanAnswerFromText(result)
        
        // Add pauses for SLOW reading (VoiceOver pauses at commas)
        result = addPausesForSlowReading(result)
        
        return result
    }
    
    /// Legacy compatibility
    func speakable(from latex: String, verbosity: Verbosity) -> String {
        return speakable(from: nil, latex: latex, verbosity: verbosity)
    }
    
    // MARK: - Main Conversion
    
    private func convertToSpeech(mathml: String?, latex: String?) -> String {
        // Priority 1: Try alttext from MathML
        if let mathml = mathml, !mathml.isEmpty {
            if let alttext = extractAltText(from: mathml), !alttext.isEmpty {
                return convertLaTeXToSpeech(alttext)
            }
            // Try parsing MathML structure
            let parsed = parseMathMLStructure(mathml)
            if !parsed.isEmpty && parsed != "equation" {
                return parsed
            }
        }
        
        // Priority 2: Convert LaTeX
        if let latex = latex, !latex.isEmpty {
            return convertLaTeXToSpeech(latex)
        }
        
        return "equation"
    }
    
    // MARK: - Add Pauses for SLOW Reading
    
    private func addPausesForSlowReading(_ text: String) -> String {
        var result = text
        
        // Add pauses after key math words (VoiceOver pauses at commas)
        let pauseAfter = [
            "equals", "plus", "minus", "times", "divided by",
            "over", "squared", "cubed", "to the power of",
            "sub", "sum", "product", "integral",
            "from", "to", "of",
            "open paren", "close paren",
            "open bracket", "close bracket",
            "square root of", "root of",
            "fraction", "end fraction",
            "numerator", "denominator",
            "limit", "approaches", "infinity",
            "sine", "cosine", "tangent",
            "log", "natural log",
            "alpha", "beta", "gamma", "delta", "theta", "pi", "sigma", "lambda", "omega"
        ]
        
        for word in pauseAfter {
            result = result.replacingOccurrences(
                of: "\(word) ",
                with: "\(word), "
            )
            if result.hasSuffix(word) {
                result = result + ","
            }
        }
        
        // Clean up double commas
        result = result.replacingOccurrences(of: ",,", with: ",")
        result = result.replacingOccurrences(of: ", ,", with: ",")
        result = result.replacingOccurrences(of: ",  ", with: ", ")
        
        return result.trimmingCharacters(in: CharacterSet(charactersIn: ", "))
    }
    
    // MARK: - Clean Answer Text
    
    private func cleanAnswerFromText(_ text: String) -> String {
        var cleaned = text
        
        let patterns = [
            #"[,.]?\s*(the\s+)?(sum|total|answer|result|area|volume|perimeter|value)\s+(is|are|=|equals)\s+[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?"#,
            #"\s+is\s+[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?$"#,
            #"\s*(=|equals)\s*[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?$"#,
            #"[,\.]\s*[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?$"#,
            #"\s*(which|that|this)\s+(is|are|equals)\s+[\d,\.]+.*$"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Extract AltText
    
    func extractAltText(from mathml: String) -> String? {
        let patterns = [
            #"alttext=["']([^"']+)["']"#,
            #"aria-label=["']([^"']+)["']"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)),
               let range = Range(match.range(at: 1), in: mathml) {
                return String(mathml[range])
            }
        }
        return nil
    }
    
    // MARK: - Parse MathML Structure
    
    private func parseMathMLStructure(_ mathml: String) -> String {
        var parts: [String] = []
        
        // 1. FRACTIONS
        if let fractionText = parseMathMLFraction(mathml) {
            parts.append(fractionText)
        }
        
        // 2. ROOTS
        if let rootText = parseMathMLRoot(mathml) {
            parts.append(rootText)
        }
        
        // 3. SUPERSCRIPTS
        let supParts = parseMathMLSuperscripts(mathml)
        parts.append(contentsOf: supParts)
        
        // 4. SUBSCRIPTS
        let subParts = parseMathMLSubscripts(mathml)
        parts.append(contentsOf: subParts)
        
        // 5. SUBSUPERSCRIPTS
        let subSupParts = parseMathMLSubSup(mathml)
        parts.append(contentsOf: subSupParts)
        
        // 6. UNDEROVER
        let underOverParts = parseMathMLUnderOver(mathml)
        parts.append(contentsOf: underOverParts)
        
        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }
        
        // Fallback: extract all content
        return extractAllMathMLContent(mathml)
    }
    
    // MARK: - MathML Fraction
    
    private func parseMathMLFraction(_ mathml: String) -> String? {
        let fracPattern = #"<mfrac[^>]*>(.*?)</mfrac>"#
        guard let regex = try? NSRegularExpression(pattern: fracPattern, options: [.dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)),
              let contentRange = Range(match.range(at: 1), in: mathml) else {
            return nil
        }
        
        let content = String(mathml[contentRange])
        
        let rowPattern = #"<mrow[^>]*>(.*?)</mrow>"#
        if let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: [.dotMatchesLineSeparators]) {
            let matches = rowRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            if matches.count >= 2,
               let numRange = Range(matches[0].range(at: 1), in: content),
               let denRange = Range(matches[1].range(at: 1), in: content) {
                let num = extractPlainText(String(content[numRange]))
                let den = extractPlainText(String(content[denRange]))
                return "fraction, \(num), over, \(den), end fraction"
            }
        }
        
        let parts = content.components(separatedBy: "</")
        if parts.count >= 2 {
            let num = extractPlainText(parts[0])
            let den = extractPlainText(parts[1])
            return "fraction, \(num), over, \(den), end fraction"
        }
        
        return nil
    }
    
    // MARK: - MathML Root
    
    private func parseMathMLRoot(_ mathml: String) -> String? {
        let sqrtPattern = #"<msqrt[^>]*>(.*?)</msqrt>"#
        if let regex = try? NSRegularExpression(pattern: sqrtPattern, options: [.dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)),
           let contentRange = Range(match.range(at: 1), in: mathml) {
            let content = extractPlainText(String(mathml[contentRange]))
            return "square root of, \(content), end root"
        }
        
        let rootPattern = #"<mroot[^>]*>(.*?)</mroot>"#
        if let regex = try? NSRegularExpression(pattern: rootPattern, options: [.dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)),
           let contentRange = Range(match.range(at: 1), in: mathml) {
            let content = extractPlainText(String(mathml[contentRange]))
            return "root of, \(content), end root"
        }
        
        return nil
    }
    
    // MARK: - MathML Superscripts
    
    private func parseMathMLSuperscripts(_ mathml: String) -> [String] {
        var results: [String] = []
        
        let supPattern = #"<msup[^>]*>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*</msup>"#
        if let regex = try? NSRegularExpression(pattern: supPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: mathml, range: NSRange(mathml.startIndex..., in: mathml))
            for match in matches {
                if let baseRange = Range(match.range(at: 1), in: mathml),
                   let expRange = Range(match.range(at: 2), in: mathml) {
                    let base = convertSymbol(String(mathml[baseRange]).trimmingCharacters(in: .whitespaces))
                    let exp = String(mathml[expRange]).trimmingCharacters(in: .whitespaces)
                    let expText = convertExponent(exp)
                    results.append("\(base), \(expText)")
                }
            }
        }
        
        return results
    }
    
    // MARK: - MathML Subscripts
    
    private func parseMathMLSubscripts(_ mathml: String) -> [String] {
        var results: [String] = []
        
        let subPattern = #"<msub[^>]*>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*</msub>"#
        if let regex = try? NSRegularExpression(pattern: subPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: mathml, range: NSRange(mathml.startIndex..., in: mathml))
            for match in matches {
                if let baseRange = Range(match.range(at: 1), in: mathml),
                   let subRange = Range(match.range(at: 2), in: mathml) {
                    let base = convertSymbol(String(mathml[baseRange]).trimmingCharacters(in: .whitespaces))
                    let sub = convertSymbol(String(mathml[subRange]).trimmingCharacters(in: .whitespaces))
                    results.append("\(base), sub, \(sub)")
                }
            }
        }
        
        return results
    }
    
    // MARK: - MathML SubSup
    
    private func parseMathMLSubSup(_ mathml: String) -> [String] {
        var results: [String] = []
        
        let subSupPattern = #"<msubsup[^>]*>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*</msubsup>"#
        if let regex = try? NSRegularExpression(pattern: subSupPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: mathml, range: NSRange(mathml.startIndex..., in: mathml))
            for match in matches {
                if let baseRange = Range(match.range(at: 1), in: mathml),
                   let subRange = Range(match.range(at: 2), in: mathml),
                   let supRange = Range(match.range(at: 3), in: mathml) {
                    let base = convertSymbol(String(mathml[baseRange]).trimmingCharacters(in: .whitespaces))
                    let sub = convertSymbol(String(mathml[subRange]).trimmingCharacters(in: .whitespaces))
                    let sup = String(mathml[supRange]).trimmingCharacters(in: .whitespaces)
                    let supText = convertExponent(sup)
                    results.append("\(base), sub, \(sub), \(supText)")
                }
            }
        }
        
        return results
    }
    
    // MARK: - MathML UnderOver
    
    private func parseMathMLUnderOver(_ mathml: String) -> [String] {
        var results: [String] = []
        
        if mathml.contains("∑") || mathml.contains("&#x2211;") || mathml.contains("sum") {
            let underOverPattern = #"<munderover[^>]*>(.*?)</munderover>"#
            if let regex = try? NSRegularExpression(pattern: underOverPattern, options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)),
               let contentRange = Range(match.range(at: 1), in: mathml) {
                let content = String(mathml[contentRange])
                let parts = extractUnderOverParts(content)
                if parts.count >= 2 {
                    results.append("sum, from, \(parts[0]), to, \(parts[1]), of")
                } else {
                    results.append("sum")
                }
            } else {
                results.append("sum")
            }
        }
        
        if mathml.contains("∫") || mathml.contains("&#x222B;") || mathml.contains("int") {
            let underOverPattern = #"<munderover[^>]*>(.*?)</munderover>"#
            if let regex = try? NSRegularExpression(pattern: underOverPattern, options: [.dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)),
               let contentRange = Range(match.range(at: 1), in: mathml) {
                let content = String(mathml[contentRange])
                let parts = extractUnderOverParts(content)
                if parts.count >= 2 {
                    results.append("integral, from, \(parts[0]), to, \(parts[1]), of")
                } else {
                    results.append("integral")
                }
            } else {
                results.append("integral")
            }
        }
        
        if mathml.contains("∏") || mathml.contains("&#x220F;") || mathml.contains("prod") {
            results.append("product")
        }
        
        return results
    }
    
    private func extractUnderOverParts(_ content: String) -> [String] {
        var parts: [String] = []
        
        let rowPattern = #"<mrow[^>]*>(.*?)</mrow>"#
        if let regex = try? NSRegularExpression(pattern: rowPattern, options: [.dotMatchesLineSeparators]) {
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            for match in matches {
                if let range = Range(match.range(at: 1), in: content) {
                    let text = extractPlainText(String(content[range]))
                    if !text.isEmpty {
                        parts.append(text)
                    }
                }
            }
        }
        
        return parts
    }
    
    // MARK: - Extract All MathML Content
    
    private func extractAllMathMLContent(_ mathml: String) -> String {
        var parts: [String] = []
        
        let miPattern = #"<mi[^>]*>([^<]+)</mi>"#
        if let regex = try? NSRegularExpression(pattern: miPattern, options: .caseInsensitive) {
            for match in regex.matches(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)) {
                if let range = Range(match.range(at: 1), in: mathml) {
                    let text = String(mathml[range]).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty {
                        parts.append(convertSymbol(text))
                    }
                }
            }
        }
        
        let mnPattern = #"<mn[^>]*>([^<]+)</mn>"#
        if let regex = try? NSRegularExpression(pattern: mnPattern, options: .caseInsensitive) {
            for match in regex.matches(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)) {
                if let range = Range(match.range(at: 1), in: mathml) {
                    let text = String(mathml[range]).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty {
                        parts.append(text)
                    }
                }
            }
        }
        
        let moPattern = #"<mo[^>]*>([^<]+)</mo>"#
        if let regex = try? NSRegularExpression(pattern: moPattern, options: .caseInsensitive) {
            for match in regex.matches(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)) {
                if let range = Range(match.range(at: 1), in: mathml) {
                    let text = String(mathml[range]).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty {
                        parts.append(convertOperator(text))
                    }
                }
            }
        }
        
        return parts.joined(separator: ", ")
    }
    
    private func extractPlainText(_ mathml: String) -> String {
        var text = mathml
        
        let tagPattern = #"<[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }
        
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return convertLaTeXToSpeech(text.trimmingCharacters(in: .whitespaces))
    }
    
    // MARK: - LaTeX to Speech
    
    private func convertLaTeXToSpeech(_ text: String) -> String {
        var result = text
        
        // Complex structures
        let complexPatterns: [(String, String)] = [
            (#"\\binom\s*\{([^}]*)\}\s*\{([^}]*)\}"#, "$1, choose, $2"),
            (#"\\frac\s*\{([^}]*)\}\s*\{([^}]*)\}"#, "fraction, $1, over, $2, end fraction"),
            (#"\\int\s*_\s*\{([^}]*)\}\s*\^\s*\{([^}]*)\}"#, "integral, from, $1, to, $2, of"),
            (#"\\int\s*_\s*(\w)\s*\^\s*(\w)"#, "integral, from, $1, to, $2, of"),
            (#"\\sum\s*_\s*\{([^}]*)\}\s*\^\s*\{([^}]*)\}"#, "sum, from, $1, to, $2, of"),
            (#"\\prod\s*_\s*\{([^}]*)\}\s*\^\s*\{([^}]*)\}"#, "product, from, $1, to, $2, of"),
            (#"\\lim\s*_\s*\{([^}]*?)\\to\s*([^}]*)\}"#, "limit, as, $1, approaches, $2, of"),
            (#"\\sqrt\s*\[([^\]]+)\]\s*\{([^}]+)\}"#, "$1 th root of, $2, end root"),
            (#"\\sqrt\s*\{([^}]+)\}"#, "square root of, $1, end root")
        ]
        
        for (pattern, replacement) in complexPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: replacement)
            }
        }
        
        // Superscripts
        let supComplexPattern = #"([a-zA-Z0-9])\s*\^\s*\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: supComplexPattern, options: []) {
            var tempResult = result
            let matches = regex.matches(in: tempResult, range: NSRange(tempResult.startIndex..., in: tempResult))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: tempResult),
                   let baseRange = Range(match.range(at: 1), in: tempResult),
                   let expRange = Range(match.range(at: 2), in: tempResult) {
                    let base = String(tempResult[baseRange])
                    let exp = String(tempResult[expRange])
                    let expSpeech = convertExponent(exp)
                    tempResult.replaceSubrange(fullRange, with: "\(base), \(expSpeech)")
                }
            }
            result = tempResult
        }
        
        // Simple replacements
        result = result.replacingOccurrences(of: "^2", with: ", squared")
        result = result.replacingOccurrences(of: "^3", with: ", cubed")
        result = result.replacingOccurrences(of: "^{-1}", with: ", to the negative one")
        result = result.replacingOccurrences(of: "_0", with: ", sub zero")
        result = result.replacingOccurrences(of: "_1", with: ", sub one")
        result = result.replacingOccurrences(of: "_2", with: ", sub two")
        result = result.replacingOccurrences(of: "_n", with: ", sub n")
        result = result.replacingOccurrences(of: "_i", with: ", sub i")
        
        // Subscript complex
        let subComplexPattern = #"([a-zA-Z])\s*_\s*\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: subComplexPattern, options: []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1, sub, $2")
        }
        
        // Simple replacements dictionary
        let replacements: [(String, String)] = [
            ("\\int", ", integral, "), ("\\sum", ", sum, "), ("\\prod", ", product, "),
            ("\\cdot", ", times, "), ("\\times", ", times, "), ("\\div", ", divided by, "),
            ("\\pm", ", plus or minus, "), ("\\leq", ", less than or equal to, "),
            ("\\geq", ", greater than or equal to, "), ("\\neq", ", not equal to, "),
            ("\\approx", ", approximately, "), ("\\infty", ", infinity, "),
            ("\\sin", ", sine of, "), ("\\cos", ", cosine of, "), ("\\tan", ", tangent of, "),
            ("\\log", ", log, "), ("\\ln", ", natural log of, "),
            ("\\alpha", ", alpha, "), ("\\beta", ", beta, "), ("\\gamma", ", gamma, "),
            ("\\delta", ", delta, "), ("\\theta", ", theta, "), ("\\pi", ", pi, "),
            ("\\sigma", ", sigma, "), ("\\lambda", ", lambda, "), ("\\omega", ", omega, "),
            ("\\Sigma", ", Sigma, "), ("\\Delta", ", Delta, "), ("\\Omega", ", Omega, "),
            ("=", ", equals, "), ("+", ", plus, "), ("-", ", minus, "),
            ("(", ", open paren, "), (")", ", close paren, "),
            ("∑", ", sum, "), ("∏", ", product, "), ("∫", ", integral, "),
            ("∞", ", infinity, "), ("π", ", pi, "), ("θ", ", theta, "),
            ("α", ", alpha, "), ("β", ", beta, "), ("γ", ", gamma, "),
            ("≤", ", less than or equal to, "), ("≥", ", greater than or equal to, "),
            ("≠", ", not equal to, "), ("≈", ", approximately, "),
            ("√", ", square root of, "), ("×", ", times, "), ("÷", ", divided by, ")
        ]
        
        for (pattern, replacement) in replacements {
            result = result.replacingOccurrences(of: pattern, with: replacement)
        }
        
        // Clean up
        result = result.replacingOccurrences(of: "\\", with: "")
        result = result.replacingOccurrences(of: "{", with: "")
        result = result.replacingOccurrences(of: "}", with: "")
        result = result.replacingOccurrences(of: "  ", with: " ")
        result = result.replacingOccurrences(of: ", ,", with: ",")
        result = result.replacingOccurrences(of: ",,", with: ",")
        
        return result.trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
    }
    
    // MARK: - Convert Exponent
    
    private func convertExponent(_ exp: String) -> String {
        let trimmed = exp.trimmingCharacters(in: .whitespaces)
        
        switch trimmed {
        case "2": return "squared"
        case "3": return "cubed"
        case "4": return "to the fourth"
        case "5": return "to the fifth"
        case "n": return "to the n"
        case "k": return "to the k"
        case "-1": return "to the negative one"
        case "-2": return "to the negative two"
        default:
            if let _ = Int(trimmed) {
                return "to the power of, \(trimmed)"
            }
            let converted = convertLaTeXToSpeech(trimmed)
            return "to the power of, \(converted)"
        }
    }
    
    // MARK: - Symbol Conversions
    
    private func convertSymbol(_ symbol: String) -> String {
        let greek: [String: String] = [
            "α": "alpha", "β": "beta", "γ": "gamma", "δ": "delta",
            "ε": "epsilon", "θ": "theta", "λ": "lambda", "μ": "mu",
            "π": "pi", "σ": "sigma", "τ": "tau", "φ": "phi",
            "ψ": "psi", "ω": "omega",
            "Γ": "Gamma", "Δ": "Delta", "Θ": "Theta", "Λ": "Lambda",
            "Σ": "Sigma", "Φ": "Phi", "Ψ": "Psi", "Ω": "Omega"
        ]
        return greek[symbol] ?? symbol
    }
    
    private func convertOperator(_ op: String) -> String {
        let operators: [String: String] = [
            "+": "plus", "-": "minus", "−": "minus",
            "=": "equals", "×": "times", "·": "times",
            "÷": "divided by", "<": "less than", ">": "greater than",
            "≤": "less than or equal to", "≥": "greater than or equal to",
            "≠": "not equal to", "≈": "approximately",
            "∑": "sum", "∏": "product", "∫": "integral"
        ]
        return operators[op] ?? op
    }
}
