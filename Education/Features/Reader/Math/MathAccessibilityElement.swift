//
//  MathAccessibilityElement.swift
//  Education
//
//  Math Mode Flow:
//    1. Double-tap (inactive)  → enter math mode → announce instructions
//    2. User CAN interrupt instructions with rotor/swipes at any time
//    3. Double-tap (math mode) → read entire equation
//    4. Rotor twist → VO shows level name; swipe up/down → VO reads part via accessibilityValue
//    5. 3-finger swipe fallback works for level/part navigation (with queued announcements)
//    6. Two-finger scrub (Z-gesture) → exit math mode
//
//  Rotor reading mechanics:
//    - Rotor predicate updates state, returns self as target
//    - VO re-focuses on self and reads accessibilityValue (the current part)
//    - NO queued announcement needed for rotor — VO handles it
//    - 3-finger swipes DO need queued announcements since VO doesn't auto-read after accessibilityScroll
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

    var next: MathNavigationLevel {
        switch self {
        case .character: return .symbol
        case .symbol: return .term
        case .term: return .structure
        case .structure: return .character
        }
    }

    var previous: MathNavigationLevel {
        switch self {
        case .character: return .structure
        case .symbol: return .character
        case .term: return .symbol
        case .structure: return .term
        }
    }
}

// MARK: - Math Mode State

private enum MathModeState {
    case inactive
    case exploringReady   // Instructions announced; waiting for user action
    case reading          // Reading full equation aloud
    case navigating       // User navigating via rotor or swipes
}

// MARK: - MathCAT Accessibility Container

class MathCATAccessibilityContainer: UIView {

    var fullEquationText: String = "equation" {
        didSet { parseEquationForNavigation() }
    }

    var mathML: String = ""
    var mathParts: [MathPart] = []

    var onEnterMathMode: (() -> Void)?
    var onExitMathMode: (() -> Void)?
    var onDismissScreen: (() -> Void)?

    // MARK: - State
    private var state: MathModeState = .inactive
    private var currentLevel: MathNavigationLevel = .term
    private var navigationParts: [[String]] = [[], [], [], []]
    private var currentIndex: Int = 0

    // MARK: - Haptics
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    // MARK: - Announcement Queue
    private var isAnnouncing = false
    private var announcementQueue: [String] = []

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
        accessibilityTraits = [.staticText]
        impactGenerator.prepare()
        selectionGenerator.prepare()
    }

    // MARK: - Accessibility Properties
    //
    // KEY INSIGHT: When rotor predicate returns self, VO reads label + value.
    // So in .navigating state:
    //   label = nil  (don't repeat noise)
    //   value = current part  (VO reads this)
    // This avoids double-reading.

    override var accessibilityLabel: String? {
        get {
            switch state {
            case .inactive:
                return "Math equation"
            case .exploringReady:
                return "Math mode active"
            case .reading:
                return nil  // Don't interfere with reading
            case .navigating:
                return nil  // Let VO just read the value
            }
        }
        set { }
    }

    override var accessibilityHint: String? {
        get {
            switch state {
            case .inactive:
                return "Double tap to explore"
            case .exploringReady:
                return "Double tap to read equation. Two finger scrub to exit."
            case .reading:
                return nil
            case .navigating:
                return nil  // Don't repeat hints on every swipe
            }
        }
        set { }
    }

    override var accessibilityValue: String? {
        get {
            if state == .navigating {
                let parts = getPartsForCurrentLevel()
                if currentIndex < parts.count {
                    return parts[currentIndex]
                }
            }
            return nil
        }
        set { }
    }

    // MARK: - Double Tap

    override func accessibilityActivate() -> Bool {
        switch state {
        case .inactive:
            enterMathMode()
            return true
        case .exploringReady, .navigating:
            readFullEquation()
            return true
        case .reading:
            return true
        }
    }

    // MARK: - Enter Math Mode

    private func enterMathMode() {
        state = .exploringReady
        currentIndex = 0
        currentLevel = .term

        impactGenerator.impactOccurred(intensity: 1.0)
        onEnterMathMode?()

        // Install rotors so they're available immediately
        accessibilityCustomRotors = buildMathRotors()

        InteractionLogger.shared.log(
            event: .mathModeEnter,
            objectType: .mathEquation,
            label: "Math Mode Entered",
            location: .zero
        )

        // Instructions. User can interrupt anytime via rotor or swipes.
        let instructions =
            "Math mode active. " +
            "Double tap to read the full equation. " +
            "Use the rotor to select a navigation level: character, symbol, term, or structure. " +
            "Then swipe up or down to move through parts. " +
            "Two finger scrub to exit math mode."
        queueAnnouncement(instructions)
    }

    // MARK: - Read Full Equation

    private func readFullEquation() {
        state = .reading

        // Clear pending (e.g. instructions) so equation reads NOW
        announcementQueue.removeAll()
        isAnnouncing = false

        impactGenerator.impactOccurred(intensity: 0.8)

        InteractionLogger.shared.log(
            event: .doubleTap,
            objectType: .mathEquation,
            label: "Read Full Equation",
            location: .zero,
            additionalInfo: String(fullEquationText.prefix(80))
        )

        let equationText = prepareTextForReading(fullEquationText)
        queueAnnouncement(equationText.isEmpty ? "Equation" : equationText)

        // After reading, transition to navigating
        let duration = Double(equationText.count) * 0.05 + 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self, self.state == .reading else { return }
            self.state = .navigating
        }
    }

    // MARK: - Exit Math Mode

    private func exitMathMode() {
        state = .inactive
        currentIndex = 0
        accessibilityCustomRotors = []

        impactGenerator.impactOccurred(intensity: 0.5)
        onExitMathMode?()

        InteractionLogger.shared.log(
            event: .mathModeExit,
            objectType: .mathEquation,
            label: "Math Mode Exited",
            location: .zero
        )

        announcementQueue.removeAll()
        isAnnouncing = false
        queueAnnouncement("Exited math mode")
    }

    // MARK: - Announcement Queue (used by 3-finger swipes and instructions, NOT by rotor)

    private func queueAnnouncement(_ text: String) {
        announcementQueue.append(text)
        processAnnouncementQueue()
    }

    private func processAnnouncementQueue() {
        guard !isAnnouncing, let announcement = announcementQueue.first else { return }
        isAnnouncing = true
        announcementQueue.removeFirst()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            UIAccessibility.post(notification: .announcement, argument: announcement)
            let dur = Double(announcement.count) * 0.045 + 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + dur) { [weak self] in
                self?.isAnnouncing = false
                self?.processAnnouncementQueue()
            }
        }
    }

    /// Stop pending instruction announcements when user starts interacting
    private func interruptAnnouncements() {
        announcementQueue.removeAll()
    }

    // MARK: - Custom Rotors
    //
    // HOW THIS WORKS:
    //   - User twists rotor → VO shows "Character" / "Symbol" / "Term" / "Structure"
    //   - User swipes up/down → predicate fires → we update currentIndex
    //   - Predicate returns self as target → VO re-focuses on self → reads accessibilityValue
    //   - accessibilityValue returns parts[currentIndex] → user hears the part
    //   - NO queued announcement → no double-reading

    private func buildMathRotors() -> [UIAccessibilityCustomRotor] {
        return MathNavigationLevel.allCases.map { level in
            UIAccessibilityCustomRotor(name: level.rawValue) { [weak self] predicate in
                guard let self = self,
                      self.state != .inactive else { return nil }

                // User is interacting — interrupt any pending instructions
                self.interruptAnnouncements()
                self.state = .navigating

                // Switch level if needed
                if self.currentLevel != level {
                    self.currentLevel = level
                    self.currentIndex = 0
                    self.impactGenerator.impactOccurred(intensity: 0.7)

                    InteractionLogger.shared.log(
                        event: .mathLevelChange,
                        objectType: .mathEquation,
                        label: "Rotor: \(level.rawValue)",
                        location: .zero,
                        rotorFunction: self.mapLevelToRotor(level)
                    )

                    // Return self — VO will read value (first part at new level)
                    return UIAccessibilityCustomRotorItemResult(targetElement: self, targetRange: nil)
                }

                // Navigate within level
                let parts = self.getPartsForCurrentLevel()
                guard !parts.isEmpty else { return nil }

                let forward = predicate.searchDirection == .next

                if forward {
                    guard self.currentIndex < parts.count - 1 else {
                        self.impactGenerator.impactOccurred(intensity: 0.3)
                        // Boundary — queue announcement since we return nil (VO won't re-read)
                        self.queueAnnouncement("End of equation")
                        return nil
                    }
                    self.currentIndex += 1
                } else {
                    guard self.currentIndex > 0 else {
                        self.impactGenerator.impactOccurred(intensity: 0.3)
                        self.queueAnnouncement("Beginning of equation")
                        return nil
                    }
                    self.currentIndex -= 1
                }

                self.selectionGenerator.selectionChanged()

                InteractionLogger.shared.log(
                    event: .mathNavigate,
                    objectType: .mathEquation,
                    label: "Rotor Navigate",
                    location: .zero,
                    additionalInfo: "\(level.rawValue) \(self.currentIndex + 1)/\(parts.count): \(parts[self.currentIndex])"
                )

                // Return self — VO reads accessibilityValue (the part)
                return UIAccessibilityCustomRotorItemResult(targetElement: self, targetRange: nil)
            }
        }
    }

    // MARK: - 3-Finger Swipe Fallback
    //
    // Unlike rotor, accessibilityScroll does NOT re-read the element.
    // So we MUST queue announcements here.

    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        guard state != .inactive else { return false }

        interruptAnnouncements()
        state = .navigating

        switch direction {
        case .up:
            changeLevelUp()
            return true
        case .down:
            changeLevelDown()
            return true
        case .right:
            if currentIndex == 0 {
                exitMathMode()
                return false // let parent handle back
            }
            navigatePrevious()
            return true
        case .left:
            navigateNext()
            return true
        default:
            return false
        }
    }

    // MARK: - Level Navigation (3-finger swipe — needs announcements)

    private func changeLevelUp() {
        currentLevel = currentLevel.next
        currentIndex = 0
        impactGenerator.impactOccurred(intensity: 0.7)
        let parts = getPartsForCurrentLevel()
        let firstPart = parts.isEmpty ? "" : ". \(parts[0])"
        queueAnnouncement("\(currentLevel.rawValue) level\(firstPart)")
    }

    private func changeLevelDown() {
        currentLevel = currentLevel.previous
        currentIndex = 0
        impactGenerator.impactOccurred(intensity: 0.7)
        let parts = getPartsForCurrentLevel()
        let firstPart = parts.isEmpty ? "" : ". \(parts[0])"
        queueAnnouncement("\(currentLevel.rawValue) level\(firstPart)")
    }

    // MARK: - Part Navigation (3-finger swipe — needs announcements)

    private func navigateNext() {
        let parts = getPartsForCurrentLevel()
        guard !parts.isEmpty else { queueAnnouncement("No parts at this level"); return }
        if currentIndex < parts.count - 1 {
            currentIndex += 1
            selectionGenerator.selectionChanged()
            queueAnnouncement(parts[currentIndex])
        } else {
            impactGenerator.impactOccurred(intensity: 0.3)
            queueAnnouncement("End of equation")
        }
    }

    private func navigatePrevious() {
        let parts = getPartsForCurrentLevel()
        guard !parts.isEmpty else { queueAnnouncement("No parts at this level"); return }
        if currentIndex > 0 {
            currentIndex -= 1
            selectionGenerator.selectionChanged()
            queueAnnouncement(parts[currentIndex])
        } else {
            impactGenerator.impactOccurred(intensity: 0.3)
            queueAnnouncement("Beginning of equation")
        }
    }

    private func getPartsForCurrentLevel() -> [String] {
        switch currentLevel {
        case .character: return navigationParts[0]
        case .symbol: return navigationParts[1]
        case .term: return navigationParts[2]
        case .structure: return navigationParts[3]
        }
    }

    private func mapLevelToRotor(_ level: MathNavigationLevel) -> RotorFunction {
        switch level {
        case .character: return .characters
        case .symbol, .term, .structure: return .mathNavigation
        }
    }

    // MARK: - Parse Equation for Navigation

    private func parseEquationForNavigation() {
        let text = fullEquationText
        guard !text.isEmpty && text != "equation" else {
            navigationParts = [["equation"], ["equation"], ["equation"], ["equation"]]
            return
        }

        // Character: each non-whitespace, non-comma char
        var characters: [String] = []
        for char in text where !char.isWhitespace && char != "," {
            characters.append(String(char))
        }

        // Symbol: space-separated tokens
        let symbols = text.components(separatedBy: " ")
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Term: comma-separated chunks
        let terms = text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Structure: group by math keywords
        var structures: [String] = []
        let keywords = ["fraction", "square root", "integral", "sum", "product", "limit", "end"]
        var buf = ""
        var inStruct = false

        for term in terms {
            let lower = term.lowercased()
            if keywords.contains(where: { lower.contains($0) && !lower.contains("end") }) {
                if !buf.isEmpty && !inStruct {
                    structures.append(buf.trimmingCharacters(in: .whitespaces))
                }
                buf = term; inStruct = true
            } else if lower.contains("end") && inStruct {
                buf += ", " + term
                structures.append(buf.trimmingCharacters(in: .whitespaces))
                buf = ""; inStruct = false
            } else if inStruct {
                buf += ", " + term
            } else {
                buf += (buf.isEmpty ? "" : ", ") + term
            }
        }
        if !buf.isEmpty { structures.append(buf.trimmingCharacters(in: .whitespaces)) }
        if structures.isEmpty { structures = [text] }

        navigationParts = [
            characters.isEmpty ? ["equation"] : characters,
            symbols.isEmpty ? ["equation"] : symbols,
            terms.isEmpty ? ["equation"] : terms,
            structures
        ]
    }

    // MARK: - Prepare Text for Reading

    private func prepareTextForReading(_ text: String) -> String {
        var cleaned = text
        for prefix in ["Equation: ", "Equation:", "equation: ", "equation:", "Math: ", "Math:"] {
            if cleaned.hasPrefix(prefix) { cleaned = String(cleaned.dropFirst(prefix.count)) }
        }

        let patterns = [
            #"[,.]?\s*(the\s+)?(sum|total|answer|result|area|volume|perimeter|value)\s+(is|are|=|equals)\s+[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?"#,
            #"\s+is\s+[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?$"#,
            #"\s*(=|equals)\s*[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?$"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
            }
        }

        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
            .replacingOccurrences(of: ", ,", with: ",")
            .replacingOccurrences(of: ",,", with: ",")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasSuffix(",") || cleaned.hasSuffix(";") {
            cleaned = String(cleaned.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return (cleaned.lowercased() == "equation" || cleaned.isEmpty) ? "" : cleaned
    }

    // MARK: - Escape (Z-scrub)

    override func accessibilityPerformEscape() -> Bool {
        if state != .inactive { exitMathMode(); return true }
        return false
    }
}

// MARK: - Substantial Math Detection
// Used by ParagraphBlockView to decide: inline text vs MathCAT block

enum MathComplexity {
    /// Check if math content is complex enough to warrant its own MathCAT block.
    /// Returns true for expressions like "2x² + 7x - 15 = 0".
    /// Returns false for simple values like "-11", "x", "15".
    static func isSubstantial(latex: String?, mathml: String?) -> Bool {
        // Check LaTeX
        if let latex = latex, !latex.isEmpty {
            let ops = ["+", "=", "\\frac", "\\sqrt", "^{", "\\sum", "\\int", "\\times", "\\cdot", "\\div", "\\leq", "\\geq"]
            let opCount = ops.filter { latex.contains($0) }.count
            if opCount >= 2 { return true }
            // Long expression with at least one operator
            if latex.count > 12 && opCount >= 1 { return true }
        }

        // Check MathML alttext
        if let mathml = mathml, !mathml.isEmpty {
            let altPatterns = [#"alttext=["']([^"']+)["']"#, #"aria-label=["']([^"']+)["']"#]
            for pattern in altPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: mathml, range: NSRange(mathml.startIndex..., in: mathml)),
                   let range = Range(match.range(at: 1), in: mathml) {
                    let alt = String(mathml[range]).lowercased()
                    let words = ["plus", "minus", "equals", "fraction", "squared", "cubed", "times", "divided", "over"]
                    let wordCount = words.filter { alt.contains($0) }.count
                    if wordCount >= 2 { return true }
                }
            }
        }

        return false
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
    var onDismissScreen: (() -> Void)?

    func makeUIView(context: Context) -> MathCATAccessibilityContainer {
        let container = MathCATAccessibilityContainer()
        container.backgroundColor = .clear

        let webView = createMathWebView()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        applyProperties(to: container)
        return container
    }

    func updateUIView(_ container: MathCATAccessibilityContainer, context: Context) {
        applyProperties(to: container)
        if let webView = container.subviews.first(where: { $0 is WKWebView }) as? WKWebView {
            loadMathContent(into: webView)
        }
    }

    private func applyProperties(to container: MathCATAccessibilityContainer) {
        container.fullEquationText = fullSpokenText
        container.mathML = mathml ?? ""
        container.mathParts = mathParts
        container.onEnterMathMode = onEnterMathMode
        container.onExitMathMode = onExitMathMode
        container.onDismissScreen = onDismissScreen
    }

    private func createMathWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        loadMathContent(into: webView)
        return webView
    }

    private func loadMathContent(into webView: WKWebView) {
        guard let mathml = mathml, !mathml.isEmpty else {
            webView.loadHTMLString(createFallbackHTML(), baseURL: nil)
            return
        }

        let cleaned = cleanMathML(mathml)
        let isDisplay = displayType?.lowercased() == "block" || displayType?.lowercased() == "display"
        let style = isDisplay ? "display: block; margin: 12px 0;" : "display: inline-block;"

        let html = """
        <!DOCTYPE html>
        <html lang="en"><head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <style>
        * { -webkit-user-select: none; user-select: none; pointer-events: none; }
        body { margin: 0; padding: 8px; background: transparent; font-family: -apple-system; }
        math { \(style) font-size: 18px; color: #121417; }
        @media (prefers-color-scheme: dark) { math { color: #FFF; } }
        </style>
        </head><body aria-hidden="true" role="presentation" inert>\(cleaned)</body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func createFallbackHTML() -> String {
        """
        <!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>* { pointer-events: none; } body { margin: 8px; font-family: -apple-system; font-size: 16px; background: transparent; }</style>
        </head><body aria-hidden="true" inert>\(latex ?? "Equation")</body></html>
        """
    }

    /// Extract <math>...</math> from LaTeXML table wrappers.
    private func cleanMathML(_ mathml: String) -> String {
        var cleaned = mathml.trimmingCharacters(in: .whitespacesAndNewlines)

        if !cleaned.hasPrefix("<math") {
            let open = #"<math\b[^>]*>"#
            let close = #"</math\s*>"#
            if let oRe = try? NSRegularExpression(pattern: open, options: .caseInsensitive),
               let cRe = try? NSRegularExpression(pattern: close, options: .caseInsensitive),
               let oM = oRe.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)),
               let cM = cRe.matches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)).last,
               let oR = Range(oM.range, in: cleaned),
               let cR = Range(cM.range, in: cleaned) {
                cleaned = String(cleaned[oR.lowerBound..<cR.upperBound])
            } else {
                cleaned = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\(cleaned)</math>"
            }
        }

        if !cleaned.contains("xmlns=") {
            cleaned = cleaned.replacingOccurrences(
                of: "<math",
                with: "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"",
                options: .caseInsensitive,
                range: cleaned.range(of: "<math", options: .caseInsensitive)
            )
        }
        return cleaned
    }
}
