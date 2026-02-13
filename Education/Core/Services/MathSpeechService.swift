//
//  MathSpeechService.swift
//  Education
//
//  Converts math (LaTeX/MathML) to spoken text for VoiceOver.
//  Handles subscripts, superscripts, fractions, integrals, summations,
//  Greek letters, implicit multiplication, and more.
//

import Foundation
import Combine

final class MathSpeechService: ObservableObject {

    enum Verbosity { case brief, verbose }

    // MARK: - Public API

    /// Convert math to spoken text.
    /// - brief: for inline math merged into paragraph text (no pauses)
    /// - verbose: for standalone block equations read aloud (pauses added)
    func speakable(from mathml: String?, latex: String?, verbosity: Verbosity) -> String {
        var result = convertToSpeech(mathml: mathml, latex: latex)
        result = cleanAnswerFromText(result)
        if verbosity == .verbose {
            result = addPausesForSlowReading(result)
        }
        return result
    }

    /// Legacy compatibility
    func speakable(from latex: String, verbosity: Verbosity) -> String {
        return speakable(from: nil, latex: latex, verbosity: verbosity)
    }

    // MARK: - Main Conversion

    private func convertToSpeech(mathml: String?, latex: String?) -> String {
        // Priority 1: alttext from MathML
        if let mathml = mathml, !mathml.isEmpty {
            if let alttext = extractAltText(from: mathml), !alttext.isEmpty {
                return convertLaTeXToSpeech(alttext)
            }
            let parsed = parseMathMLStructure(mathml)
            if !parsed.isEmpty && parsed != "equation" {
                return parsed
            }
        }
        // Priority 2: LaTeX
        if let latex = latex, !latex.isEmpty {
            return convertLaTeXToSpeech(latex)
        }
        return "equation"
    }

    // MARK: - LaTeX to Speech (MAIN METHOD)

    private func convertLaTeXToSpeech(_ text: String) -> String {
        var result = text

        // 1. Complex structures (order matters — do these first)
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
            if let regex = try? NSRegularExpression(pattern: pattern) {
                result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: replacement)
            }
        }

        // 2. Superscripts with braces: x^{2} → x, squared
        let supComplexPattern = #"([a-zA-Z0-9])\s*\^\s*\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: supComplexPattern) {
            var temp = result
            let matches = regex.matches(in: temp, range: NSRange(temp.startIndex..., in: temp))
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: temp),
                   let baseRange = Range(match.range(at: 1), in: temp),
                   let expRange = Range(match.range(at: 2), in: temp) {
                    let base = String(temp[baseRange])
                    let exp = String(temp[expRange])
                    temp.replaceSubrange(fullRange, with: "\(base), \(convertExponent(exp))")
                }
            }
            result = temp
        }

        // 3. Simple superscripts/subscripts
        result = result.replacingOccurrences(of: "^2", with: " squared")
        result = result.replacingOccurrences(of: "^3", with: " cubed")
        result = result.replacingOccurrences(of: "^{-1}", with: ", to the negative one")
        result = result.replacingOccurrences(of: "_0", with: " sub zero")
        result = result.replacingOccurrences(of: "_1", with: " sub one")
        result = result.replacingOccurrences(of: "_2", with: " sub two")
        result = result.replacingOccurrences(of: "_n", with: " sub n")
        result = result.replacingOccurrences(of: "_i", with: " sub i")

        // 4. Subscript with braces
        let subComplexPattern = #"([a-zA-Z])\s*_\s*\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: subComplexPattern) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "$1, sub, $2")
        }

        // 5. Delimiters
        result = result.replacingOccurrences(of: "\\left(", with: " open paren ")
        result = result.replacingOccurrences(of: "\\right)", with: " close paren ")
        result = result.replacingOccurrences(of: "\\left[", with: " open bracket ")
        result = result.replacingOccurrences(of: "\\right]", with: " close bracket ")
        result = result.replacingOccurrences(of: "\\left\\{", with: " open brace ")
        result = result.replacingOccurrences(of: "\\right\\}", with: " close brace ")
        result = result.replacingOccurrences(of: "\\left|", with: " absolute value of ")
        result = result.replacingOccurrences(of: "\\right|", with: " end absolute value ")
        result = result.replacingOccurrences(of: "\\left", with: "")
        result = result.replacingOccurrences(of: "\\right", with: "")

        // 6. Command replacements
        let replacements: [(String, String)] = [
            ("\\int", " integral "), ("\\sum", " sum "), ("\\prod", " product "),
            ("\\cdot", " times "), ("\\times", " times "), ("\\div", " divided by "),
            ("\\pm", " plus or minus "), ("\\leq", " less than or equal to "),
            ("\\geq", " greater than or equal to "), ("\\neq", " not equal to "),
            ("\\approx", " approximately "), ("\\infty", " infinity "),
            ("\\sin", " sine of "), ("\\cos", " cosine of "), ("\\tan", " tangent of "),
            ("\\log", " log "), ("\\ln", " natural log of "),
            ("\\alpha", " alpha "), ("\\beta", " beta "), ("\\gamma", " gamma "),
            ("\\delta", " delta "), ("\\theta", " theta "), ("\\pi", " pi "),
            ("\\sigma", " sigma "), ("\\lambda", " lambda "), ("\\omega", " omega "),
            ("\\Sigma", " Sigma "), ("\\Delta", " Delta "), ("\\Omega", " Omega "),
        ]
        for (cmd, spoken) in replacements {
            result = result.replacingOccurrences(of: cmd, with: spoken)
        }

        // 7. Operators and symbols (after commands, so \leq doesn't get hit by < rule)
        result = result.replacingOccurrences(of: "=", with: " equals ")
        result = result.replacingOccurrences(of: "+", with: " plus ")
        // Careful with minus: don't break negative numbers like -11
        // Replace " - " (spaced minus) and "- " at start
        result = result.replacingOccurrences(of: " - ", with: " minus ")
        result = result.replacingOccurrences(of: "(", with: " open paren ")
        result = result.replacingOccurrences(of: ")", with: " close paren ")

        // Unicode symbols
        let unicodeReplacements: [(String, String)] = [
            ("∑", " sum "), ("∏", " product "), ("∫", " integral "),
            ("∞", " infinity "), ("π", " pi "), ("θ", " theta "),
            ("α", " alpha "), ("β", " beta "), ("γ", " gamma "),
            ("≤", " less than or equal to "), ("≥", " greater than or equal to "),
            ("≠", " not equal to "), ("≈", " approximately "),
            ("√", " square root of "), ("×", " times "), ("÷", " divided by "),
            ("−", " minus "),  // Unicode minus (U+2212)
        ]
        for (sym, spoken) in unicodeReplacements {
            result = result.replacingOccurrences(of: sym, with: spoken)
        }

        // 8. Clean up LaTeX artifacts
        result = result.replacingOccurrences(of: "\\", with: "")
        result = result.replacingOccurrences(of: "{", with: "")
        result = result.replacingOccurrences(of: "}", with: "")

        // 9.Split implicit multiplication ***
        // "ax" → "a, x"   "2x" → "2 x"   "7x" → "7 x"   "rs" → "r, s"
        // But don't split known words: "sin", "cos", "of", "the", "end", etc.
        result = splitImplicitMultiplication(result)

        // 10. Final cleanup
        result = result.replacingOccurrences(of: "  ", with: " ")
        result = result.replacingOccurrences(of: ", ,", with: ",")
        result = result.replacingOccurrences(of: ",,", with: ",")

        return result.trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
    }

    // MARK: - Split Implicit Multiplication
    //
    // "ax" in math means "a times x" but VoiceOver reads it as "axe".
    // This method inserts spaces/commas between adjacent letters that
    // represent separate variables, and between digits and letters.
    //
    // Rules:
    //   - "ax" → "a, x"       (two single-letter variables)
    //   - "2x" → "2 x"        (digit then letter)
    //   - "7x" → "7 x"
    //   - "abc" → "a, b, c"   (three variables)
    //   - "sin" → "sin"       (known function, don't split)
    //   - "equals" → "equals" (known word, don't split)
    //   - "15" → "15"         (number, don't split)

    private func splitImplicitMultiplication(_ text: String) -> String {
        // Known words that should NOT be split
        let knownWords: Set<String> = [
            "sin", "cos", "tan", "log", "ln", "lim", "mod", "max", "min", "abs", "det",
            "equals", "plus", "minus", "times", "divided", "over", "by",
            "fraction", "squared", "cubed", "root", "end",
            "sum", "product", "integral", "limit", "approaches", "infinity",
            "alpha", "beta", "gamma", "delta", "theta", "sigma", "lambda", "omega", "pi",
            "epsilon", "phi", "psi", "mu", "tau",
            "Sigma", "Delta", "Omega", "Gamma", "Theta", "Lambda", "Phi", "Psi",
            "paren", "bracket", "brace", "open", "close",
            "of", "from", "to", "the", "power", "sub", "natural",
            "less", "than", "equal", "greater", "not", "approximately", "or",
            "value", "absolute",
        ]

        // Split text into words (whitespace-separated)
        let words = text.components(separatedBy: " ")
        var processed: [String] = []

        for word in words {
            let trimmed = word.trimmingCharacters(in: CharacterSet(charactersIn: ",. "))

            // Skip empty, known words, pure numbers
            if trimmed.isEmpty {
                processed.append(word)
                continue
            }
            if knownWords.contains(trimmed.lowercased()) {
                processed.append(word)
                continue
            }
            if trimmed.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," }) {
                processed.append(word)
                continue
            }
            // Single character — fine as is
            if trimmed.count <= 1 {
                processed.append(word)
                continue
            }

            // Check if this looks like implicit multiplication
            let chars = Array(trimmed)
            let hasLetters = chars.contains(where: { $0.isLetter })
            let hasDigits = chars.contains(where: { $0.isNumber })
            let allLetters = chars.allSatisfy({ $0.isLetter })

            if allLetters && trimmed.count <= 4 && !knownWords.contains(trimmed.lowercased()) {
                // Pure letters, short, not a known word → split: "ax" → "a, x"
                // Preserve any trailing punctuation from original word
                let suffix = word.hasSuffix(",") ? "," : ""
                let split = chars.map { String($0) }.joined(separator: ", ")
                processed.append(split + suffix)
            } else if hasDigits && hasLetters {
                // Mixed digits+letters like "2x", "7x", "15a" → split at digit-letter boundary
                let suffix = word.hasSuffix(",") ? "," : ""
                let split = splitDigitLetterBoundary(trimmed)
                processed.append(split + suffix)
            } else {
                processed.append(word)
            }
        }

        return processed.joined(separator: " ")
    }

    /// Split at boundaries between digits and letters: "2x" → "2, x", "15ab" → "15, a, b"
    private func splitDigitLetterBoundary(_ text: String) -> String {
        var result = ""
        var prevWasDigit = false
        var prevWasLetter = false

        for char in text {
            let isDigit = char.isNumber
            let isLetter = char.isLetter

            if isLetter && prevWasDigit {
                result += ", " + String(char)
            } else if isDigit && prevWasLetter {
                result += ", " + String(char)
            } else if isLetter && prevWasLetter {
                // Two adjacent letters in a mixed token → separate them
                result += ", " + String(char)
            } else {
                result += String(char)
            }

            prevWasDigit = isDigit
            prevWasLetter = isLetter
        }

        return result
    }

    // MARK: - Add Pauses for Verbose Reading

    private func addPausesForSlowReading(_ text: String) -> String {
        var result = text

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
            result = result.replacingOccurrences(of: "\(word) ", with: "\(word), ")
            if result.hasSuffix(word) { result += "," }
        }

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
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
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
        if let t = parseMathMLFraction(mathml) { parts.append(t) }
        if let t = parseMathMLRoot(mathml) { parts.append(t) }
        parts.append(contentsOf: parseMathMLSuperscripts(mathml))
        parts.append(contentsOf: parseMathMLSubscripts(mathml))
        parts.append(contentsOf: parseMathMLSubSup(mathml))
        parts.append(contentsOf: parseMathMLUnderOver(mathml))
        if !parts.isEmpty { return parts.joined(separator: " ") }
        return extractAllMathMLContent(mathml)
    }

    private func parseMathMLFraction(_ mathml: String) -> String? {
        let pattern = #"<mfrac[^>]*>(.*?)</mfrac>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators),
              let match = regex.firstMatch(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)),
              let range = Range(match.range(at: 1), in: mathml) else { return nil }
        let content = String(mathml[range])
        let rowPattern = #"<mrow[^>]*>(.*?)</mrow>"#
        if let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: .dotMatchesLineSeparators) {
            let matches = rowRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            if matches.count >= 2,
               let numRange = Range(matches[0].range(at: 1), in: content),
               let denRange = Range(matches[1].range(at: 1), in: content) {
                return "fraction, \(extractPlainText(String(content[numRange]))), over, \(extractPlainText(String(content[denRange]))), end fraction"
            }
        }
        return nil
    }

    private func parseMathMLRoot(_ mathml: String) -> String? {
        let sqrtPattern = #"<msqrt[^>]*>(.*?)</msqrt>"#
        if let regex = try? NSRegularExpression(pattern: sqrtPattern, options: .dotMatchesLineSeparators),
           let match = regex.firstMatch(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)),
           let range = Range(match.range(at: 1), in: mathml) {
            return "square root of, \(extractPlainText(String(mathml[range]))), end root"
        }
        let rootPattern = #"<mroot[^>]*>(.*?)</mroot>"#
        if let regex = try? NSRegularExpression(pattern: rootPattern, options: .dotMatchesLineSeparators),
           let match = regex.firstMatch(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)),
           let range = Range(match.range(at: 1), in: mathml) {
            return "root of, \(extractPlainText(String(mathml[range]))), end root"
        }
        return nil
    }

    private func parseMathMLSuperscripts(_ mathml: String) -> [String] {
        var results: [String] = []
        let pattern = #"<msup[^>]*>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*</msup>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) {
            for match in regex.matches(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)) {
                if let baseRange = Range(match.range(at: 1), in: mathml),
                   let expRange = Range(match.range(at: 2), in: mathml) {
                    let base = convertSymbol(String(mathml[baseRange]).trimmingCharacters(in: .whitespaces))
                    let exp = String(mathml[expRange]).trimmingCharacters(in: .whitespaces)
                    results.append("\(base), \(convertExponent(exp))")
                }
            }
        }
        return results
    }

    private func parseMathMLSubscripts(_ mathml: String) -> [String] {
        var results: [String] = []
        let pattern = #"<msub[^>]*>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*</msub>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) {
            for match in regex.matches(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)) {
                if let baseRange = Range(match.range(at: 1), in: mathml),
                   let subRange = Range(match.range(at: 2), in: mathml) {
                    results.append("\(convertSymbol(String(mathml[baseRange]).trimmingCharacters(in: .whitespaces))), sub, \(convertSymbol(String(mathml[subRange]).trimmingCharacters(in: .whitespaces)))")
                }
            }
        }
        return results
    }

    private func parseMathMLSubSup(_ mathml: String) -> [String] {
        var results: [String] = []
        let pattern = #"<msubsup[^>]*>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*</msubsup>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) {
            for match in regex.matches(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)) {
                if let baseRange = Range(match.range(at: 1), in: mathml),
                   let subRange = Range(match.range(at: 2), in: mathml),
                   let supRange = Range(match.range(at: 3), in: mathml) {
                    let base = convertSymbol(String(mathml[baseRange]).trimmingCharacters(in: .whitespaces))
                    let sub = convertSymbol(String(mathml[subRange]).trimmingCharacters(in: .whitespaces))
                    let sup = convertExponent(String(mathml[supRange]).trimmingCharacters(in: .whitespaces))
                    results.append("\(base), sub, \(sub), \(sup)")
                }
            }
        }
        return results
    }

    private func parseMathMLUnderOver(_ mathml: String) -> [String] {
        var results: [String] = []
        if mathml.contains("∑") || mathml.contains("&#x2211;") { results.append("sum") }
        if mathml.contains("∫") || mathml.contains("&#x222B;") { results.append("integral") }
        if mathml.contains("∏") || mathml.contains("&#x220F;") { results.append("product") }
        return results
    }

    private func extractAllMathMLContent(_ mathml: String) -> String {
        var parts: [String] = []
        let tagPatterns: [(String, (String) -> String)] = [
            (#"<mi[^>]*>([^<]+)</mi>"#, { self.convertSymbol($0) }),
            (#"<mn[^>]*>([^<]+)</mn>"#, { $0 }),
            (#"<mo[^>]*>([^<]+)</mo>"#, { self.convertOperator($0) })
        ]
        for (pattern, transform) in tagPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                for match in regex.matches(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)) {
                    if let range = Range(match.range(at: 1), in: mathml) {
                        let text = String(mathml[range]).trimmingCharacters(in: .whitespaces)
                        if !text.isEmpty { parts.append(transform(text)) }
                    }
                }
            }
        }
        return parts.joined(separator: " ")
    }

    private func extractPlainText(_ mathml: String) -> String {
        var text = mathml
        if let regex = try? NSRegularExpression(pattern: #"<[^>]+>"#) {
            text = regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        }
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return convertLaTeXToSpeech(text.trimmingCharacters(in: .whitespaces))
    }

    // MARK: - Convert Exponent

    private func convertExponent(_ exp: String) -> String {
        let t = exp.trimmingCharacters(in: .whitespaces)
        switch t {
        case "2": return "squared"
        case "3": return "cubed"
        case "4": return "to the fourth"
        case "5": return "to the fifth"
        case "n": return "to the n"
        case "k": return "to the k"
        case "-1": return "to the negative one"
        case "-2": return "to the negative two"
        default:
            if Int(t) != nil { return "to the power of \(t)" }
            return "to the power of \(convertLaTeXToSpeech(t))"
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
