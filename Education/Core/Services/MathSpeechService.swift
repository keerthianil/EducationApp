//
//  MathSpeechService.swift
//  Education
//
//  Converts math (LaTeX/MathML) to spoken text for VoiceOver.
//

import Foundation
import Combine

final class MathSpeechService: ObservableObject {

    enum Verbosity { case brief, verbose }

    // MARK: - Public API

    func speakable(from mathml: String?, latex: String?, verbosity: Verbosity) -> String {
        var result = convertToSpeech(mathml: mathml, latex: latex)
        if verbosity == .verbose {
            result = addPausesForSlowReading(result)
        }
        return result
    }

    func speakable(from latex: String, verbosity: Verbosity) -> String {
        speakable(from: nil, latex: latex, verbosity: verbosity)
    }

    // MARK: - Main Conversion

    private func convertToSpeech(mathml: String?, latex: String?) -> String {
        if let mathml = mathml, !mathml.isEmpty {
            if let alt = extractAltText(from: mathml), !alt.isEmpty {
                return convertLaTeXToSpeech(alt)
            }
            let parsed = parseMathMLStructure(mathml)
            if !parsed.isEmpty && parsed != "equation" { return parsed }
        }
        if let latex = latex, !latex.isEmpty {
            return convertLaTeXToSpeech(latex)
        }
        return "equation"
    }

    // MARK: - LaTeX / Alttext → Speech

    private func convertLaTeXToSpeech(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 0. Decode HTML entities FIRST
        s = decodeHTMLEntities(s)

        // 1. Insert spaces around bare operators
        s = insertSpacesAroundOperators(s)

        // 2. Complex structures (fractions, roots, integrals, sums)
        let complex: [(String, String)] = [
            (#"\\binom\s*\{([^}]*)\}\s*\{([^}]*)\}"#, "$1 choose $2"),
            (#"\\frac\s*\{([^}]*)\}\s*\{([^}]*)\}"#, "fraction, $1, over, $2, end fraction"),
            (#"\\int\s*_\s*\{([^}]*)\}\s*\^\s*\{([^}]*)\}"#, "integral from $1 to $2 of"),
            (#"\\int\s*_\s*(\w)\s*\^\s*(\w)"#, "integral from $1 to $2 of"),
            (#"\\sum\s*_\s*\{([^}]*)\}\s*\^\s*\{([^}]*)\}"#, "sum from $1 to $2 of"),
            (#"\\prod\s*_\s*\{([^}]*)\}\s*\^\s*\{([^}]*)\}"#, "product from $1 to $2 of"),
            (#"\\lim\s*_\s*\{([^}]*?)\\to\s*([^}]*)\}"#, "limit as $1 approaches $2 of"),
            (#"\\sqrt\s*\[([^\]]+)\]\s*\{([^}]+)\}"#, "$1 th root of $2 end root"),
            (#"\\sqrt\s*\{([^}]+)\}"#, "square root of $1 end root"),
        ]
        for (pat, rep) in complex {
            if let rx = try? NSRegularExpression(pattern: pat) {
                s = rx.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: rep)
            }
        }

        // 3. Superscripts with braces
        let supPat = #"([a-zA-Z0-9\)\]])\s*\^\s*\{([^}]+)\}"#
        if let rx = try? NSRegularExpression(pattern: supPat) {
            var t = s
            for m in rx.matches(in: t, range: NSRange(t.startIndex..., in: t)).reversed() {
                if let full = Range(m.range, in: t),
                   let bR = Range(m.range(at: 1), in: t),
                   let eR = Range(m.range(at: 2), in: t) {
                    t.replaceSubrange(full, with: "\(t[bR]) \(exponent(String(t[eR])))")
                }
            }
            s = t
        }
        // Standalone ^{n} (no captured base)
        if let rx = try? NSRegularExpression(pattern: #"\^\s*\{([^}]+)\}"#) {
            var t = s
            for m in rx.matches(in: t, range: NSRange(t.startIndex..., in: t)).reversed() {
                if let full = Range(m.range, in: t), let eR = Range(m.range(at: 1), in: t) {
                    t.replaceSubrange(full, with: " \(exponent(String(t[eR])))")
                }
            }
            s = t
        }

        // 4. Subscripts with braces  x_{n}
        if let rx = try? NSRegularExpression(pattern: #"([a-zA-Z])\s*_\s*\{([^}]+)\}"#) {
            s = rx.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "$1 sub $2")
        }

        // 5. Simple super/subscripts (no braces)
        s = s.replacingOccurrences(of: "^2", with: " squared")
        s = s.replacingOccurrences(of: "^3", with: " cubed")
        s = s.replacingOccurrences(of: "^{-1}", with: " to the negative one")
        let simpleSubs: [(String,String)] = [("_0"," sub zero"),("_1"," sub one"),("_2"," sub two"),("_n"," sub n"),("_i"," sub i")]
        for (k,v) in simpleSubs { s = s.replacingOccurrences(of: k, with: v) }

        // 6. Delimiters
        let delims: [(String,String)] = [
            ("\\left(", " open paren "), ("\\right)", " close paren "),
            ("\\left[", " open bracket "), ("\\right]", " close bracket "),
            ("\\left\\{", " open brace "), ("\\right\\}", " close brace "),
            ("\\left|", " absolute value of "), ("\\right|", " end absolute value "),
            ("\\left", ""), ("\\right", ""),
        ]
        for (k,v) in delims { s = s.replacingOccurrences(of: k, with: v) }

        // 7. LaTeX commands → spoken
        let cmds: [(String,String)] = [
            ("\\int"," integral "),("\\sum"," sum "),("\\prod"," product "),
            ("\\cdot"," times "),("\\times"," times "),("\\div"," divided by "),
            ("\\pm"," plus or minus "),("\\leq"," less than or equal to "),
            ("\\geq"," greater than or equal to "),("\\neq"," not equal to "),
            ("\\approx"," approximately "),("\\infty"," infinity "),
            ("\\sin"," sine of "),("\\cos"," cosine of "),("\\tan"," tangent of "),
            ("\\log"," log "),("\\ln"," natural log of "),
            ("\\alpha"," alpha "),("\\beta"," beta "),("\\gamma"," gamma "),
            ("\\delta"," delta "),("\\theta"," theta "),("\\pi"," pi "),
            ("\\sigma"," sigma "),("\\lambda"," lambda "),("\\omega"," omega "),
            ("\\Sigma"," Sigma "),("\\Delta"," Delta "),("\\Omega"," Omega "),
        ]
        for (k,v) in cmds { s = s.replacingOccurrences(of: k, with: v) }

        // 8. Bare operators (AFTER LaTeX commands so \leq isn't hit by < rule)
        s = s.replacingOccurrences(of: "=", with: " equals ")
        s = s.replacingOccurrences(of: "+", with: " plus ")
        s = s.replacingOccurrences(of: " - ", with: " minus ")
        s = s.replacingOccurrences(of: ">", with: " greater than ")
        s = s.replacingOccurrences(of: "<", with: " less than ")
        s = s.replacingOccurrences(of: "(", with: " open paren ")
        s = s.replacingOccurrences(of: ")", with: " close paren ")

        // 9. Unicode symbols
        let uni: [(String,String)] = [
            ("∑"," sum "),("∏"," product "),("∫"," integral "),
            ("∞"," infinity "),("π"," pi "),("θ"," theta "),
            ("α"," alpha "),("β"," beta "),("γ"," gamma "),
            ("≤"," less than or equal to "),("≥"," greater than or equal to "),
            ("≠"," not equal to "),("≈"," approximately "),
            ("√"," square root of "),("×"," times "),("÷"," divided by "),
            ("−"," minus "),   // U+2212 unicode minus
            ("\u{2062}"," "),  // invisible times — just a space, splitImplicit handles it
        ]
        for (k,v) in uni { s = s.replacingOccurrences(of: k, with: v) }

        // 10. Strip remaining LaTeX artifacts
        s = s.replacingOccurrences(of: "\\", with: "")
        s = s.replacingOccurrences(of: "{", with: "")
        s = s.replacingOccurrences(of: "}", with: "")

        // 10b. Catch ^2 ^3 that only became visible after brace removal
        s = s.replacingOccurrences(of: "^2", with: " squared")
        s = s.replacingOccurrences(of: "^3", with: " cubed")
        if let rx = try? NSRegularExpression(pattern: #"\^(\d)"#) {
            s = rx.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: " to the power of $1")
        }

        // 11. Split implicit multiplication  
        s = splitImplicitMultiplication(s)

        // 12. Final whitespace cleanup
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        s = s.replacingOccurrences(of: ", ,", with: ",")
        s = s.replacingOccurrences(of: ",,", with: ",")
        return s.trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
    }

    // MARK: - HTML Entity Decoding

    private func decodeHTMLEntities(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&lt;", with: "<")
        s = s.replacingOccurrences(of: "&gt;", with: ">")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        s = s.replacingOccurrences(of: "&apos;", with: "'")
        s = s.replacingOccurrences(of: "&#x2212;", with: "−")
        s = s.replacingOccurrences(of: "&#x2013;", with: "–")
        s = s.replacingOccurrences(of: "&#x00D7;", with: "×")
        if let rx = try? NSRegularExpression(pattern: #"&#(\d+);"#) {
            var r = s
            for m in rx.matches(in: r, range: NSRange(r.startIndex..., in: r)).reversed() {
                if let full = Range(m.range, in: r),
                   let nR = Range(m.range(at: 1), in: r),
                   let code = UInt32(r[nR]),
                   let scalar = Unicode.Scalar(code) {
                    r.replaceSubrange(full, with: String(scalar))
                }
            }
            s = r
        }
        return s
    }

    // MARK: - Insert Spaces Around Operators

    private func insertSpacesAroundOperators(_ text: String) -> String {
        var s = text
        let ops: [(String, String)] = [
            (#"([a-zA-Z0-9\)])\-([a-zA-Z0-9\(])"#, "$1 - $2"),
            (#"([a-zA-Z0-9\)])\=([a-zA-Z0-9\(])"#, "$1 = $2"),
            (#"([a-zA-Z0-9\)])\+([a-zA-Z0-9\(])"#, "$1 + $2"),
            (#"([a-zA-Z0-9\)])>([a-zA-Z0-9\(])"#,  "$1 > $2"),
            (#"([a-zA-Z0-9\)])<([a-zA-Z0-9\(])"#,  "$1 < $2"),
        ]
        for (pat, rep) in ops {
            if let rx = try? NSRegularExpression(pattern: pat) {
                var prev = ""
                while prev != s {
                    prev = s
                    s = rx.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: rep)
                }
            }
        }
        return s
    }

    // MARK: - Split Implicit Multiplication
    //
    //   "ax" → "a. times. x"   (periods become VoiceOver pauses)
    //   "2x" → "2 times x"

    private func splitImplicitMultiplication(_ text: String) -> String {
        let known: Set<String> = [
            "sin","cos","tan","log","ln","lim","mod","max","min","abs","det",
            "equals","plus","minus","times","divided","over","by",
            "fraction","squared","cubed","root","end",
            "sum","product","integral","limit","approaches","infinity",
            "alpha","beta","gamma","delta","theta","sigma","lambda","omega","pi",
            "epsilon","phi","psi","mu","tau",
            "paren","bracket","brace","open","close",
            "of","from","to","the","power","sub","natural","negative",
            "less","than","equal","greater","not","approximately","or",
            "value","absolute",
        ]

        return text.components(separatedBy: " ").map { word -> String in
            let t = word.trimmingCharacters(in: CharacterSet(charactersIn: ",."))
            if t.isEmpty || known.contains(t.lowercased()) { return word }
            if t.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," }) { return word }
            if t.count <= 1 { return word }

            let chars = Array(t)
            let hasLetters = chars.contains { $0.isLetter }
            let hasDigits  = chars.contains { $0.isNumber }
            let allLetters = chars.allSatisfy { $0.isLetter }
            let suffix = word.hasSuffix(",") ? "," : ""

            if allLetters && t.count <= 4 && !known.contains(t.lowercased()) {
                // "ax" → "a, times, x"  — commas give VoiceOver natural pauses
                return chars.map { String($0) }.joined(separator: ", times, ") + suffix
            }
            if hasDigits && hasLetters {
                return splitDigitLetter(t) + suffix
            }
            return word
        }.joined(separator: " ")
    }

    private func splitDigitLetter(_ text: String) -> String {
        var r = ""
        var prevDigit = false, prevLetter = false
        for c in text {
            let d = c.isNumber, l = c.isLetter
            if l && prevDigit { r += ", times, \(c)" }
            else if d && prevLetter { r += " \(c)" }
            else if l && prevLetter { r += ", times, \(c)" }
            else { r += String(c) }
            prevDigit = d; prevLetter = l
        }
        return r
    }

    // MARK: - Pauses for Verbose

    private func addPausesForSlowReading(_ text: String) -> String {
        var r = text
        let words = [
            "equals","plus","minus","times","divided by","over",
            "squared","cubed","to the power of","sub",
            "sum","product","integral","from","to","of",
            "open paren","close paren","open bracket","close bracket",
            "square root of","root of","fraction","end fraction",
            "limit","approaches","infinity",
            "sine","cosine","tangent","log","natural log",
            "greater than","less than",
            "alpha","beta","gamma","delta","theta","pi","sigma","lambda","omega",
        ]
        for w in words {
            r = r.replacingOccurrences(of: "\(w) ", with: "\(w), ")
            if r.hasSuffix(w) { r += "," }
        }
        r = r.replacingOccurrences(of: ",,", with: ",")
        r = r.replacingOccurrences(of: ", ,", with: ",")
        r = r.replacingOccurrences(of: ",  ", with: ", ")
        return r.trimmingCharacters(in: CharacterSet(charactersIn: ", "))
    }

    // MARK: - Exponent Helper

    private func exponent(_ exp: String) -> String {
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

    // MARK: - Extract AltText

    func extractAltText(from mathml: String) -> String? {
        for attr in ["alttext", "aria-label"] {
            let pat = "\(attr)=[\"']([^\"']+)[\"']"
            if let rx = try? NSRegularExpression(pattern: pat, options: .caseInsensitive),
               let m = rx.firstMatch(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)),
               let r = Range(m.range(at: 1), in: mathml) {
                return String(mathml[r])
            }
        }
        return nil
    }

    // MARK: - MathML Structure Parsing

    private func parseMathMLStructure(_ mathml: String) -> String {
        var parts: [String] = []
        if let t = parseFrac(mathml) { parts.append(t) }
        if let t = parseRoot(mathml) { parts.append(t) }
        parts += parseSups(mathml)
        parts += parseSubs(mathml)
        parts += parseSubSups(mathml)
        parts += parseUnderOver(mathml)
        if !parts.isEmpty { return parts.joined(separator: " ") }
        return extractAllContent(mathml)
    }

    private func parseFrac(_ ml: String) -> String? {
        guard let rx = try? NSRegularExpression(pattern: #"<mfrac[^>]*>(.*?)</mfrac>"#, options: .dotMatchesLineSeparators),
              let m = rx.firstMatch(in: ml, range: NSRange(ml.startIndex..., in: ml)),
              let r = Range(m.range(at: 1), in: ml) else { return nil }
        let c = String(ml[r])
        guard let rr = try? NSRegularExpression(pattern: #"<mrow[^>]*>(.*?)</mrow>"#, options: .dotMatchesLineSeparators) else { return nil }
        let ms = rr.matches(in: c, range: NSRange(c.startIndex..., in: c))
        guard ms.count >= 2, let n = Range(ms[0].range(at: 1), in: c), let d = Range(ms[1].range(at: 1), in: c) else { return nil }
        return "fraction, \(plainText(String(c[n]))), over, \(plainText(String(c[d]))), end fraction"
    }

    private func parseRoot(_ ml: String) -> String? {
        if let rx = try? NSRegularExpression(pattern: #"<msqrt[^>]*>(.*?)</msqrt>"#, options: .dotMatchesLineSeparators),
           let m = rx.firstMatch(in: ml, range: NSRange(ml.startIndex..., in: ml)),
           let r = Range(m.range(at: 1), in: ml) {
            return "square root of, \(plainText(String(ml[r]))), end root"
        }
        return nil
    }

    private func parseSups(_ ml: String) -> [String] {
        var out: [String] = []
        let pat = #"<msup[^>]*>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*</msup>"#
        if let rx = try? NSRegularExpression(pattern: pat, options: .dotMatchesLineSeparators) {
            for m in rx.matches(in: ml, range: NSRange(ml.startIndex..., in: ml)) {
                if let b = Range(m.range(at: 1), in: ml), let e = Range(m.range(at: 2), in: ml) {
                    out.append("\(sym(String(ml[b]))) \(exponent(String(ml[e]).trimmingCharacters(in: .whitespaces)))")
                }
            }
        }
        return out
    }

    private func parseSubs(_ ml: String) -> [String] {
        var out: [String] = []
        let pat = #"<msub[^>]*>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*</msub>"#
        if let rx = try? NSRegularExpression(pattern: pat, options: .dotMatchesLineSeparators) {
            for m in rx.matches(in: ml, range: NSRange(ml.startIndex..., in: ml)) {
                if let b = Range(m.range(at: 1), in: ml), let s = Range(m.range(at: 2), in: ml) {
                    out.append("\(sym(String(ml[b]))), sub, \(sym(String(ml[s])))")
                }
            }
        }
        return out
    }

    private func parseSubSups(_ ml: String) -> [String] {
        var out: [String] = []
        let pat = #"<msubsup[^>]*>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*<m[ion][^>]*>([^<]*)</m[ion]>\s*</msubsup>"#
        if let rx = try? NSRegularExpression(pattern: pat, options: .dotMatchesLineSeparators) {
            for m in rx.matches(in: ml, range: NSRange(ml.startIndex..., in: ml)) {
                if let b = Range(m.range(at: 1), in: ml), let sb = Range(m.range(at: 2), in: ml), let sp = Range(m.range(at: 3), in: ml) {
                    out.append("\(sym(String(ml[b]))), sub, \(sym(String(ml[sb]))), \(exponent(String(ml[sp]).trimmingCharacters(in: .whitespaces)))")
                }
            }
        }
        return out
    }

    private func parseUnderOver(_ ml: String) -> [String] {
        var r: [String] = []
        if ml.contains("∑") || ml.contains("&#x2211;") { r.append("sum") }
        if ml.contains("∫") || ml.contains("&#x222B;") { r.append("integral") }
        if ml.contains("∏") || ml.contains("&#x220F;") { r.append("product") }
        return r
    }

    private func extractAllContent(_ ml: String) -> String {
        var parts: [String] = []
        let tags: [(String, (String)->String)] = [
            (#"<mi[^>]*>([^<]+)</mi>"#, { self.sym($0) }),
            (#"<mn[^>]*>([^<]+)</mn>"#, { $0 }),
            (#"<mo[^>]*>([^<]+)</mo>"#, { self.op($0) }),
        ]
        for (pat, fn) in tags {
            if let rx = try? NSRegularExpression(pattern: pat, options: .caseInsensitive) {
                for m in rx.matches(in: ml, range: NSRange(ml.startIndex..., in: ml)) {
                    if let r = Range(m.range(at: 1), in: ml) {
                        let t = String(ml[r]).trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty { parts.append(fn(t)) }
                    }
                }
            }
        }
        return parts.joined(separator: " ")
    }

    private func plainText(_ ml: String) -> String {
        var t = ml
        if let rx = try? NSRegularExpression(pattern: #"<[^>]+>"#) {
            t = rx.stringByReplacingMatches(in: t, range: NSRange(t.startIndex..., in: t), withTemplate: " ")
        }
        return convertLaTeXToSpeech(t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces))
    }

    private func sym(_ s: String) -> String {
        let g: [String:String] = [
            "α":"alpha","β":"beta","γ":"gamma","δ":"delta","ε":"epsilon",
            "θ":"theta","λ":"lambda","μ":"mu","π":"pi","σ":"sigma",
            "τ":"tau","φ":"phi","ψ":"psi","ω":"omega",
            "Γ":"Gamma","Δ":"Delta","Θ":"Theta","Λ":"Lambda",
            "Σ":"Sigma","Φ":"Phi","Ψ":"Psi","Ω":"Omega",
        ]
        return g[s.trimmingCharacters(in: .whitespaces)] ?? s.trimmingCharacters(in: .whitespaces)
    }

    private func op(_ o: String) -> String {
        let m: [String:String] = [
            "+":"plus","-":"minus","−":"minus","=":"equals",
            "×":"times","·":"times","÷":"divided by",
            "<":"less than",">":"greater than",
            "≤":"less than or equal to","≥":"greater than or equal to",
            "≠":"not equal to","≈":"approximately",
            "∑":"sum","∏":"product","∫":"integral",
        ]
        return m[o] ?? o
    }
}
