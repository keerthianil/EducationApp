//
//  MathAccessibilityElement.swift
//  Education
//
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
    case exploringReady
    case reading
    case navigating
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
    // --- NEW: Callback to dismiss the entire screen (for 3-finger back in math mode) ---
    var onDismissScreen: (() -> Void)?
    
    // MARK: - State Machine
    private var state: MathModeState = .inactive
    
    // MARK: - Navigation State
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
        // --- CHANGED: Removed .isButton so VO does NOT say "button" ---
        accessibilityTraits = [.staticText]
        impactGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    // MARK: - Accessibility Label
    
    override var accessibilityLabel: String? {
        get {
            switch state {
            case .inactive:
                return "Math equation"
            case .exploringReady:
                return "Math mode active"
            case .reading:
                return "Reading equation"
            case .navigating:
                let levelName = currentLevel.rawValue
                let parts = getPartsForCurrentLevel()
                if currentIndex < parts.count {
                    return "\(levelName) level, \(parts[currentIndex])"
                }
                return "Navigating by \(levelName)"
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
                return "Double tap to read equation. Swipe up or down to change level. Swipe left or right to navigate."
            case .reading:
                return "Reading"
            case .navigating:
                return "Swipe left or right to navigate. Swipe up or down to change level. Double tap to read all. Two finger scrub to exit."
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
    
    // MARK: - Double Tap Action
    
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
    // --- CHANGED: Instructions FIRST, clearer wording ---
    
    private func enterMathMode() {
        state = .exploringReady
        currentIndex = 0
        currentLevel = .term
        
        impactGenerator.impactOccurred(intensity: 1.0)
        onEnterMathMode?()
        
        InteractionLogger.shared.log(
            event: .mathModeEnter,
            objectType: .mathEquation,
            label: "Math Mode Entered",
            location: .zero,
            additionalInfo: "Instructions announced first"
        )
        
        // --- CHANGED: Clear, detailed instructions ---
        let instructions = "Math mode active. " +
            "Swipe up or down with three fingers to change navigation level between character, symbol, term, and structure. " +
            "Swipe left or right with three fingers to move through equation parts. " +
            "Double tap to read the full equation. " +
            "Two finger scrub to exit math mode."
        queueAnnouncement(instructions)
    }
    
    // MARK: - Read Full Equation
    
    private func readFullEquation() {
        state = .reading
        
        impactGenerator.impactOccurred(intensity: 0.8)
        
        InteractionLogger.shared.log(
            event: .doubleTap,
            objectType: .mathEquation,
            label: "Read Full Equation",
            location: .zero,
            additionalInfo: "Reading equation aloud"
        )
        
        let equationText = prepareTextForReading(fullEquationText)
        
        if equationText.isEmpty {
            queueAnnouncement("Equation")
        } else {
            queueAnnouncement(equationText)
        }
        
        let readingDuration = Double(equationText.count) * 0.045 + 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + readingDuration) { [weak self] in
            guard let self = self else { return }
            if self.state == .reading {
                self.state = .navigating
            }
        }
    }
    
    // MARK: - Exit Math Mode
    
    private func exitMathMode() {
        state = .inactive
        currentIndex = 0
        
        impactGenerator.impactOccurred(intensity: 0.5)
        onExitMathMode?()
        
        InteractionLogger.shared.log(
            event: .mathModeExit,
            objectType: .mathEquation,
            label: "Math Mode Exited",
            location: .zero,
            additionalInfo: "Returned to normal navigation"
        )
        
        queueAnnouncement("Exited math mode")
    }
    
    // MARK: - Announcement Queue
    
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
            
            let duration = Double(announcement.count) * 0.045 + 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.isAnnouncing = false
                self?.processAnnouncementQueue()
            }
        }
    }
    
    // MARK: - Swipe Navigation
    // --- CHANGED: .right at beginning exits math mode, returns false so parent handles back ---
    
    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        guard state == .exploringReady || state == .navigating else {
            // Not in math mode - don't capture
            return false
        }
        
        state = .navigating
        
        switch direction {
        case .up:
            InteractionLogger.shared.log(event: .swipeUp, objectType: .mathEquation, label: "Math Swipe Up", location: .zero, additionalInfo: "Change to more detailed level")
            changeLevelUp()
            return true
            
        case .down:
            InteractionLogger.shared.log(event: .swipeDown, objectType: .mathEquation, label: "Math Swipe Down", location: .zero, additionalInfo: "Change to less detailed level")
            changeLevelDown()
            return true
            
        case .right:
            // --- CHANGED: At beginning, exit math mode and let parent handle back ---
            if currentIndex == 0 {
                exitMathMode()
                // Return false so the 3-finger swipe propagates to parent for back navigation
                return false
            }
            InteractionLogger.shared.log(event: .swipeRight, objectType: .mathEquation, label: "Math Swipe Right", location: .zero, additionalInfo: "Navigate to previous part")
            navigatePrevious()
            return true
            
        case .left:
            InteractionLogger.shared.log(event: .swipeLeft, objectType: .mathEquation, label: "Math Swipe Left", location: .zero, additionalInfo: "Navigate to next part")
            navigateNext()
            return true
            
        default:
            return false
        }
    }
    
    // MARK: - Level Navigation
    
    private func changeLevelUp() {
        let previousLevel = currentLevel
        currentLevel = currentLevel.next
        currentIndex = 0
        impactGenerator.impactOccurred(intensity: 0.7)
        
        let parts = getPartsForCurrentLevel()
        let firstPart = parts.isEmpty ? "" : ", \(parts[0])"
        
        InteractionLogger.shared.log(event: .mathLevelChange, objectType: .mathEquation, label: "Level Up", location: .zero, rotorFunction: mapLevelToRotor(currentLevel), additionalInfo: "From \(previousLevel.rawValue) to \(currentLevel.rawValue)")
        
        queueAnnouncement("\(currentLevel.rawValue) level\(firstPart)")
    }
    
    private func changeLevelDown() {
        let previousLevel = currentLevel
        currentLevel = currentLevel.previous
        currentIndex = 0
        impactGenerator.impactOccurred(intensity: 0.7)
        
        let parts = getPartsForCurrentLevel()
        let firstPart = parts.isEmpty ? "" : ", \(parts[0])"
        
        InteractionLogger.shared.log(event: .mathLevelChange, objectType: .mathEquation, label: "Level Down", location: .zero, rotorFunction: mapLevelToRotor(currentLevel), additionalInfo: "From \(previousLevel.rawValue) to \(currentLevel.rawValue)")
        
        queueAnnouncement("\(currentLevel.rawValue) level\(firstPart)")
    }
    
    private func mapLevelToRotor(_ level: MathNavigationLevel) -> RotorFunction {
        switch level {
        case .character: return .characters
        case .symbol: return .mathNavigation
        case .term: return .mathNavigation
        case .structure: return .mathNavigation
        }
    }
    
    // MARK: - Part Navigation
    
    private func navigateNext() {
        let parts = getPartsForCurrentLevel()
        guard !parts.isEmpty else {
            queueAnnouncement("No parts at this level")
            return
        }
        
        if currentIndex < parts.count - 1 {
            currentIndex += 1
            selectionGenerator.selectionChanged()
            InteractionLogger.shared.log(event: .mathNavigate, objectType: .mathEquation, label: "Navigate Next", location: .zero, additionalInfo: "Index \(currentIndex) of \(parts.count): \(parts[currentIndex])")
            queueAnnouncement(parts[currentIndex])
        } else {
            impactGenerator.impactOccurred(intensity: 0.3)
            InteractionLogger.shared.log(event: .mathNavigate, objectType: .mathEquation, label: "Navigate Next - End", location: .zero, additionalInfo: "Reached end of equation")
            queueAnnouncement("End of equation")
        }
    }
    
    private func navigatePrevious() {
        let parts = getPartsForCurrentLevel()
        guard !parts.isEmpty else {
            queueAnnouncement("No parts at this level")
            return
        }
        
        if currentIndex > 0 {
            currentIndex -= 1
            selectionGenerator.selectionChanged()
            InteractionLogger.shared.log(event: .mathNavigate, objectType: .mathEquation, label: "Navigate Previous", location: .zero, additionalInfo: "Index \(currentIndex) of \(parts.count): \(parts[currentIndex])")
            queueAnnouncement(parts[currentIndex])
        } else {
            impactGenerator.impactOccurred(intensity: 0.3)
            InteractionLogger.shared.log(event: .mathNavigate, objectType: .mathEquation, label: "Navigate Previous - Beginning", location: .zero, additionalInfo: "Reached beginning of equation")
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
    
    // MARK: - Parse Equation for Navigation
    
    private func parseEquationForNavigation() {
        let text = fullEquationText
        guard !text.isEmpty && text != "equation" else {
            navigationParts = [["equation"], ["equation"], ["equation"], ["equation"]]
            return
        }
        
        var characters: [String] = []
        for char in text where !char.isWhitespace && char != "," {
            characters.append(String(char))
        }
        
        let symbolPattern = text.components(separatedBy: " ")
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let terms = text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var structures: [String] = []
        let structureKeywords = ["fraction", "square root", "integral", "sum", "product", "limit", "end"]
        
        var currentStructure = ""
        var inStructure = false
        
        for term in terms {
            let lower = term.lowercased()
            if structureKeywords.contains(where: { lower.contains($0) && !lower.contains("end") }) {
                if !currentStructure.isEmpty && !inStructure {
                    structures.append(currentStructure.trimmingCharacters(in: .whitespaces))
                }
                currentStructure = term
                inStructure = true
            } else if lower.contains("end") && inStructure {
                currentStructure += ", " + term
                structures.append(currentStructure.trimmingCharacters(in: .whitespaces))
                currentStructure = ""
                inStructure = false
            } else if inStructure {
                currentStructure += ", " + term
            } else {
                currentStructure += (currentStructure.isEmpty ? "" : ", ") + term
            }
        }
        
        if !currentStructure.isEmpty {
            structures.append(currentStructure.trimmingCharacters(in: .whitespaces))
        }
        
        if structures.isEmpty { structures = [text] }
        
        navigationParts = [
            characters.isEmpty ? ["equation"] : characters,
            symbolPattern.isEmpty ? ["equation"] : symbolPattern,
            terms.isEmpty ? ["equation"] : terms,
            structures
        ]
    }
    
    // MARK: - Prepare Text for Reading
    
    private func prepareTextForReading(_ text: String) -> String {
        var cleaned = text
        let prefixes = ["Equation: ", "Equation:", "equation: ", "equation:", "Math: ", "Math:"]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) { cleaned = String(cleaned.dropFirst(prefix.count)) }
        }
        
        let answerPatterns = [
            #"[,.]?\s*(the\s+)?(sum|total|answer|result|area|volume|perimeter|value)\s+(is|are|=|equals)\s+[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?"#,
            #"\s+is\s+[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?$"#,
            #"\s*(=|equals)\s*[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?$"#
        ]
        for pattern in answerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
            }
        }
        
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        cleaned = cleaned.replacingOccurrences(of: ", ,", with: ",")
        cleaned = cleaned.replacingOccurrences(of: ",,", with: ",")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasSuffix(",") || cleaned.hasSuffix(";") {
            cleaned = String(cleaned.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        if cleaned.lowercased() == "equation" || cleaned.isEmpty { return "" }
        return cleaned
    }
    
    // MARK: - Escape Action
    
    override func accessibilityPerformEscape() -> Bool {
        if state != .inactive {
            exitMathMode()
            return true
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
        
        container.fullEquationText = fullSpokenText
        container.mathML = mathml ?? ""
        container.mathParts = mathParts
        container.onEnterMathMode = onEnterMathMode
        container.onExitMathMode = onExitMathMode
        container.onDismissScreen = onDismissScreen
        
        return container
    }
    
    func updateUIView(_ container: MathCATAccessibilityContainer, context: Context) {
        container.fullEquationText = fullSpokenText
        container.mathML = mathml ?? ""
        container.mathParts = mathParts
        container.onEnterMathMode = onEnterMathMode
        container.onExitMathMode = onExitMathMode
        container.onDismissScreen = onDismissScreen
        
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
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>* { pointer-events: none; } body { margin: 8px; font-family: -apple-system; font-size: 16px; background: transparent; }</style>
        </head><body aria-hidden="true" inert>\(displayText)</body></html>
        """
    }
    
    private func cleanMathML(_ mathml: String) -> String {
        var cleaned = mathml.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.hasPrefix("<math") {
            cleaned = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\(cleaned)</math>"
        }
        if !cleaned.contains("xmlns=") {
            cleaned = cleaned.replacingOccurrences(of: "<math", with: "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"", options: .caseInsensitive)
        }
        return cleaned
    }
}
