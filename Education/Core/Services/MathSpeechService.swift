//
//  MathSpeechService.swift
//  Education
//
//  MATHCAT-LIKE: Full conversion of complex math to speech
//  Handles subscripts, superscripts, fractions, integrals, summations,
//  Greek letters, matrices, roots, binomials, and more.
//
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
            // Add comma after the word if not already followed by comma or period
            result = result.replacingOccurrences(
                of: "\(word) ",
                with: "\(word), "
            )
            // Handle end of string
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
    
    // MARK: - Parse MathML Structure (COMPREHENSIVE)
    
    private func parseMathMLStructure(_ mathml: String) -> String {
        var parts: [String] = []
        
        // 1. FRACTIONS: <mfrac>
        if let fractionText = parseMathMLFraction(mathml) {
            parts.append(fractionText)
        }
        
        // 2. ROOTS: <msqrt>, <mroot>
        if let rootText = parseMathMLRoot(mathml) {
            parts.append(rootText)
        }
        
        // 3. SUPERSCRIPTS: <msup>
        let supParts = parseMathMLSuperscripts(mathml)
        parts.append(contentsOf: supParts)
        
        // 4. SUBSCRIPTS: <msub>
        let subParts = parseMathMLSubscripts(mathml)
        parts.append(contentsOf: subParts)
        
        // 5. SUBSUPERSCRIPTS: <msubsup>
        let subSupParts = parseMathMLSubSup(mathml)
        parts.append(contentsOf: subSupParts)
        
        // 6. UNDEROVER: <munderover> for sums, integrals with limits
        let underOverParts = parseMathMLUnderOver(mathml)
        parts.append(contentsOf: underOverParts)
        
        // If we found structured elements, return them
        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }
        
        // 7. Fallback: extract all content in order
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
        
        // Extract numerator and denominator
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
        
        // Simple fraction without mrow
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
        // Square root
        let sqrtPattern = #"<msqrt[^>]*>(.*?)</msqrt>"#
        if let regex = try? NSRegularExpression(pattern: sqrtPattern, options: [.dotMatchesLineSeparators]),
           let match = regex.firstMatch(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)),
           let contentRange = Range(match.range(at: 1), in: mathml) {
            let content = extractPlainText(String(mathml[contentRange]))
            return "square root of, \(content), end root"
        }
        
        // nth root
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
        
        // Pattern: <msup><mi>x</mi><mn>2</mn></msup>
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
        
        // Pattern: <msub><mi>x</mi><mn>n</mn></msub>
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
    
    // MARK: - MathML SubSup (both subscript and superscript)
    
    private func parseMathMLSubSup(_ mathml: String) -> [String] {
        var results: [String] = []
        
        // Pattern: <msubsup><mi>x</mi><mn>i</mn><mn>2</mn></msubsup>
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
    
    // MARK: - MathML UnderOver (sums, integrals with limits)
    
    private func parseMathMLUnderOver(_ mathml: String) -> [String] {
        var results: [String] = []
        
        // Check for sum symbol
        if mathml.contains("∑") || mathml.contains("&#x2211;") || mathml.contains("sum") {
            // Try to extract limits
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
        
        // Check for integral symbol
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
        
        // Check for product symbol
        if mathml.contains("∏") || mathml.contains("&#x220F;") || mathml.contains("prod") {
            results.append("product")
        }
        
        return results
    }
    
    private func extractUnderOverParts(_ content: String) -> [String] {
        var parts: [String] = []
        
        // Extract <mrow> elements
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
        
        // Extract <mi> (identifiers)
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
        
        // Extract <mn> (numbers)
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
        
        // Extract <mo> (operators)
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
        
        // Remove tags
        let tagPattern = #"<[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }
        
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return convertLaTeXToSpeech(text.trimmingCharacters(in: .whitespaces))
    }
    
    // MARK: - LaTeX to Speech (COMPREHENSIVE MATHCAT-LIKE)
    
    private func convertLaTeXToSpeech(_ text: String) -> String {
        var result = text
        
        // ==================== COMPLEX STRUCTURES ====================
        
        // BINOMIAL: \binom{n}{k} → "n choose k"
        let binomPattern = #"\\binom\s*\{([^}]*)\}\s*\{([^}]*)\}"#
        if let regex = try? NSRegularExpression(pattern: binomPattern, options: []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1, choose, $2")
        }
        
        // FRACTION: \frac{a}{b} → "a over b"
        let fracPattern = #"\\frac\s*\{([^}]*)\}\s*\{([^}]*)\}"#
        if let regex = try? NSRegularExpression(pattern: fracPattern, options: []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "fraction, $1, over, $2, end fraction")
        }
        
        // INTEGRAL WITH LIMITS: \int_{a}^{b} → "integral from a to b of"
        let intLimitPattern = #"\\int\s*_\s*\{([^}]*)\}\s*\^\s*\{([^}]*)\}"#
        if let regex = try? NSRegularExpression(pattern: intLimitPattern, options: []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "integral, from, $1, to, $2, of")
        }
        
        // INTEGRAL WITH SIMPLE LIMITS: \int_a^b
        let intSimplePattern = #"\\int\s*_\s*(\w)\s*\^\s*(\w)"#
        if let regex = try? NSRegularExpression(pattern: intSimplePattern, options: []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "integral, from, $1, to, $2, of")
        }
        
        // SUM WITH LIMITS: \sum_{k=0}^{n} → "sum from k equals 0 to n of"
        let sumLimitPattern = #"\\sum\s*_\s*\{([^}]*)\}\s*\^\s*\{([^}]*)\}"#
        if let regex = try? NSRegularExpression(pattern: sumLimitPattern, options: []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "sum, from, $1, to, $2, of")
        }
        
        // PRODUCT WITH LIMITS: \prod_{k=1}^{n}
        let prodLimitPattern = #"\\prod\s*_\s*\{([^}]*)\}\s*\^\s*\{([^}]*)\}"#
        if let regex = try? NSRegularExpression(pattern: prodLimitPattern, options: []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "product, from, $1, to, $2, of")
        }
        
        // LIMIT: \lim_{x \to a} → "limit as x approaches a of"
        let limPattern = #"\\lim\s*_\s*\{([^}]*?)\\to\s*([^}]*)\}"#
        if let regex = try? NSRegularExpression(pattern: limPattern, options: []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "limit, as, $1, approaches, $2, of")
        }
        
        // NTH ROOT: \sqrt[n]{x} → "nth root of x"
        let nthRootPattern = #"\\sqrt\s*\[([^\]]+)\]\s*\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: nthRootPattern, options: []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1 th root of, $2, end root")
        }
        
        // SQUARE ROOT: \sqrt{x} → "square root of x"
        let sqrtPattern = #"\\sqrt\s*\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: sqrtPattern, options: []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "square root of, $1, end root")
        }
        
        // ==================== SUPERSCRIPTS ====================
        
        // Complex superscript: x^{n+1} → "x to the power of n plus 1"
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
        
        // Simple superscripts
        result = result.replacingOccurrences(of: "^2", with: ", squared")
        result = result.replacingOccurrences(of: "^3", with: ", cubed")
        result = result.replacingOccurrences(of: "^4", with: ", to the fourth")
        result = result.replacingOccurrences(of: "^5", with: ", to the fifth")
        result = result.replacingOccurrences(of: "^n", with: ", to the n")
        result = result.replacingOccurrences(of: "^k", with: ", to the k")
        result = result.replacingOccurrences(of: "^x", with: ", to the x")
        result = result.replacingOccurrences(of: "^{-1}", with: ", to the negative one")
        result = result.replacingOccurrences(of: "^{-2}", with: ", to the negative two")
        
        // ==================== SUBSCRIPTS ====================
        
        // Complex subscript: x_{i+1} → "x sub i plus 1"
        let subComplexPattern = #"([a-zA-Z])\s*_\s*\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: subComplexPattern, options: []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1, sub, $2")
        }
        
        // Simple subscripts
        result = result.replacingOccurrences(of: "_0", with: ", sub zero")
        result = result.replacingOccurrences(of: "_1", with: ", sub one")
        result = result.replacingOccurrences(of: "_2", with: ", sub two")
        result = result.replacingOccurrences(of: "_3", with: ", sub three")
        result = result.replacingOccurrences(of: "_n", with: ", sub n")
        result = result.replacingOccurrences(of: "_k", with: ", sub k")
        result = result.replacingOccurrences(of: "_i", with: ", sub i")
        result = result.replacingOccurrences(of: "_j", with: ", sub j")
        result = result.replacingOccurrences(of: "_x", with: ", sub x")
        result = result.replacingOccurrences(of: "_y", with: ", sub y")
        
        // ==================== SIMPLE REPLACEMENTS ====================
        
        let replacements: [(String, String)] = [
            // Calculus
            ("\\int", ", integral, "),
            ("\\iint", ", double integral, "),
            ("\\iiint", ", triple integral, "),
            ("\\oint", ", contour integral, "),
            ("\\partial", ", partial, "),
            ("\\nabla", ", del, "),
            ("\\sum", ", sum, "),
            ("\\prod", ", product, "),
            ("\\lim", ", limit, "),
            ("\\to", ", approaches, "),
            ("\\rightarrow", ", approaches, "),
            ("\\infty", ", infinity, "),
            ("d/dx", ", d d x of, "),
            ("dy/dx", ", d y d x, "),
            
            // Operations
            ("\\cdot", ", times, "),
            ("\\times", ", times, "),
            ("\\div", ", divided by, "),
            ("\\pm", ", plus or minus, "),
            ("\\mp", ", minus or plus, "),
            ("\\ast", ", asterisk, "),
            
            // Comparisons
            ("\\leq", ", less than or equal to, "),
            ("\\geq", ", greater than or equal to, "),
            ("\\neq", ", not equal to, "),
            ("\\approx", ", approximately, "),
            ("\\equiv", ", equivalent to, "),
            ("\\sim", ", similar to, "),
            ("\\propto", ", proportional to, "),
            ("\\ll", ", much less than, "),
            ("\\gg", ", much greater than, "),
            
            // Trig functions
            ("\\sin", ", sine of, "),
            ("\\cos", ", cosine of, "),
            ("\\tan", ", tangent of, "),
            ("\\cot", ", cotangent of, "),
            ("\\sec", ", secant of, "),
            ("\\csc", ", cosecant of, "),
            ("\\arcsin", ", arc sine of, "),
            ("\\arccos", ", arc cosine of, "),
            ("\\arctan", ", arc tangent of, "),
            ("\\sinh", ", hyperbolic sine of, "),
            ("\\cosh", ", hyperbolic cosine of, "),
            ("\\tanh", ", hyperbolic tangent of, "),
            
            // Logarithms
            ("\\log", ", log, "),
            ("\\ln", ", natural log of, "),
            ("\\exp", ", e to the, "),
            
            // Greek lowercase
            ("\\alpha", ", alpha, "),
            ("\\beta", ", beta, "),
            ("\\gamma", ", gamma, "),
            ("\\delta", ", delta, "),
            ("\\epsilon", ", epsilon, "),
            ("\\varepsilon", ", epsilon, "),
            ("\\zeta", ", zeta, "),
            ("\\eta", ", eta, "),
            ("\\theta", ", theta, "),
            ("\\vartheta", ", theta, "),
            ("\\iota", ", iota, "),
            ("\\kappa", ", kappa, "),
            ("\\lambda", ", lambda, "),
            ("\\mu", ", mu, "),
            ("\\nu", ", nu, "),
            ("\\xi", ", xi, "),
            ("\\pi", ", pi, "),
            ("\\rho", ", rho, "),
            ("\\sigma", ", sigma, "),
            ("\\tau", ", tau, "),
            ("\\upsilon", ", upsilon, "),
            ("\\phi", ", phi, "),
            ("\\varphi", ", phi, "),
            ("\\chi", ", chi, "),
            ("\\psi", ", psi, "),
            ("\\omega", ", omega, "),
            
            // Greek uppercase
            ("\\Gamma", ", Gamma, "),
            ("\\Delta", ", Delta, "),
            ("\\Theta", ", Theta, "),
            ("\\Lambda", ", Lambda, "),
            ("\\Xi", ", Xi, "),
            ("\\Pi", ", Pi, "),
            ("\\Sigma", ", Sigma, "),
            ("\\Phi", ", Phi, "),
            ("\\Psi", ", Psi, "),
            ("\\Omega", ", Omega, "),
            
            // Set theory
            ("\\in", ", in, "),
            ("\\notin", ", not in, "),
            ("\\subset", ", subset of, "),
            ("\\supset", ", superset of, "),
            ("\\subseteq", ", subset or equal to, "),
            ("\\supseteq", ", superset or equal to, "),
            ("\\cup", ", union, "),
            ("\\cap", ", intersection, "),
            ("\\emptyset", ", empty set, "),
            ("\\forall", ", for all, "),
            ("\\exists", ", there exists, "),
            
            // Brackets
            ("\\left(", ", open paren, "),
            ("\\right)", ", close paren, "),
            ("\\left[", ", open bracket, "),
            ("\\right]", ", close bracket, "),
            ("\\left\\{", ", open brace, "),
            ("\\right\\}", ", close brace, "),
            ("\\langle", ", open angle, "),
            ("\\rangle", ", close angle, "),
            
            // Basic operators
            ("=", ", equals, "),
            ("+", ", plus, "),
            ("-", ", minus, "),
            ("(", ", open paren, "),
            (")", ", close paren, "),
            ("[", ", open bracket, "),
            ("]", ", close bracket, "),
            
            // Unicode symbols
            ("∑", ", sum, "),
            ("∏", ", product, "),
            ("∫", ", integral, "),
            ("∬", ", double integral, "),
            ("∭", ", triple integral, "),
            ("∞", ", infinity, "),
            ("∂", ", partial, "),
            ("∇", ", del, "),
            ("π", ", pi, "),
            ("θ", ", theta, "),
            ("α", ", alpha, "),
            ("β", ", beta, "),
            ("γ", ", gamma, "),
            ("δ", ", delta, "),
            ("ε", ", epsilon, "),
            ("σ", ", sigma, "),
            ("λ", ", lambda, "),
            ("μ", ", mu, "),
            ("ω", ", omega, "),
            ("φ", ", phi, "),
            ("ψ", ", psi, "),
            ("Σ", ", Sigma, "),
            ("Δ", ", Delta, "),
            ("Ω", ", Omega, "),
            ("Π", ", Pi, "),
            ("−", ", minus, "),
            ("×", ", times, "),
            ("÷", ", divided by, "),
            ("±", ", plus or minus, "),
            ("≠", ", not equal to, "),
            ("≤", ", less than or equal to, "),
            ("≥", ", greater than or equal to, "),
            ("≈", ", approximately, "),
            ("√", ", square root of, "),
            ("∈", ", in, "),
            ("∉", ", not in, "),
            ("⊂", ", subset of, "),
            ("⊃", ", superset of, "),
            ("∪", ", union, "),
            ("∩", ", intersection, "),
            ("∅", ", empty set, "),
            ("∀", ", for all, "),
            ("∃", ", there exists, "),
            ("→", ", approaches, "),
            ("←", ", from, "),
            ("↔", ", if and only if, "),
            
            // Invisible operators
            ("\u{2062}", " "),
            ("\u{2061}", " "),
            ("\u{2063}", " "),
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
        case "6": return "to the sixth"
        case "7": return "to the seventh"
        case "8": return "to the eighth"
        case "9": return "to the ninth"
        case "10": return "to the tenth"
        case "n": return "to the n"
        case "k": return "to the k"
        case "m": return "to the m"
        case "x": return "to the x"
        case "y": return "to the y"
        case "-1": return "to the negative one"
        case "-2": return "to the negative two"
        case "n+1": return "to the n plus one"
        case "n-1": return "to the n minus one"
        case "2n": return "to the two n"
        default:
            if let _ = Int(trimmed) {
                return "to the power of, \(trimmed)"
            }
            // Complex expression
            let converted = convertLaTeXToSpeech(trimmed)
            return "to the power of, \(converted)"
        }
    }
    
    // MARK: - Symbol Conversions
    
    private func convertSymbol(_ symbol: String) -> String {
        let greek: [String: String] = [
            "α": "alpha", "β": "beta", "γ": "gamma", "δ": "delta",
            "ε": "epsilon", "ζ": "zeta", "η": "eta", "θ": "theta",
            "ι": "iota", "κ": "kappa", "λ": "lambda", "μ": "mu",
            "ν": "nu", "ξ": "xi", "π": "pi", "ρ": "rho",
            "σ": "sigma", "τ": "tau", "υ": "upsilon", "φ": "phi",
            "χ": "chi", "ψ": "psi", "ω": "omega",
            "Γ": "Gamma", "Δ": "Delta", "Θ": "Theta", "Λ": "Lambda",
            "Ξ": "Xi", "Π": "Pi", "Σ": "Sigma", "Φ": "Phi",
            "Ψ": "Psi", "Ω": "Omega"
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
            "∑": "sum", "∏": "product", "∫": "integral",
            "(": "open paren", ")": "close paren",
            "[": "open bracket", "]": "close bracket",
            "{": "open brace", "}": "close brace"
        ]
        return operators[op] ?? op
    }
}
