//
//  MathAccessibilityElement.swift
//  Education
//
//
//  Flow:
//  1. Focus: "Math equation. Double tap to explore."
//  2. First double tap: Enter math mode → Announce instructions ONLY
//  3. Second double tap: Read ENTIRE equation
//  4. Swipe up/down: Change navigation level
//  5. Swipe left/right: Navigate through equation parts
//  6. Third double tap: Exit math mode
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
    case inactive           // Not in math mode - double tap to enter
    case exploringReady     // In math mode, instructions announced - double tap to read
    case reading            // Currently reading equation
    case navigating         // User is navigating with swipes
}

// MARK: - MathCAT Accessibility Container (FIXED)

class MathCATAccessibilityContainer: UIView {
    
    // The full equation spoken text
    var fullEquationText: String = "equation" {
        didSet {
            parseEquationForNavigation()
        }
    }
    
    // MathML for reference
    var mathML: String = ""
    
    // Kept for compatibility
    var mathParts: [MathPart] = []
    
    // Callbacks
    var onEnterMathMode: (() -> Void)?
    var onExitMathMode: (() -> Void)?
    
    // MARK: - State Machine
    private var state: MathModeState = .inactive
    
    // MARK: - Navigation State
    private var currentLevel: MathNavigationLevel = .term
    private var navigationParts: [[String]] = [[], [], [], []] // character, symbol, term, structure
    private var currentIndex: Int = 0
    
    // MARK: - Haptics
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    // MARK: - Announcement Queue (prevents overlap)
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
        accessibilityTraits = [.button, .staticText]
        impactGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    // MARK: - Accessibility Label (changes based on state)
    
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
                return "Double tap to read equation. Swipe to navigate."
            case .reading:
                return "Reading"
            case .navigating:
                return "Swipe left or right to navigate. Double tap to read all."
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
    
    // MARK: - Double Tap Action (State Machine)
    
    override func accessibilityActivate() -> Bool {
        switch state {
        case .inactive:
            // Enter math mode - announce instructions ONLY
            enterMathMode()
            return true
            
        case .exploringReady, .navigating:
            // Read the entire equation
            readFullEquation()
            return true
            
        case .reading:
            // Already reading - do nothing or exit
            return true
        }
    }
    
    // MARK: - Enter Math Mode (Instructions Only)
    
    private func enterMathMode() {
        state = .exploringReady
        currentIndex = 0
        currentLevel = .term
        
        impactGenerator.impactOccurred(intensity: 1.0)
        onEnterMathMode?()
        
        // Announce instructions ONLY - no equation yet
        let instructions = "Math mode. Swipe up or down to change level. Swipe left or right to navigate. Double tap to read equation."
        
        queueAnnouncement(instructions)
    }
    
    // MARK: - Read Full Equation (No Interruptions)
    
    private func readFullEquation() {
        state = .reading
        
        impactGenerator.impactOccurred(intensity: 0.8)
        
        // Get clean equation text
        let equationText = prepareTextForReading(fullEquationText)
        
        if equationText.isEmpty {
            queueAnnouncement("Equation")
        } else {
            queueAnnouncement(equationText)
        }
        
        // After reading completes, go to navigating state
        let readingDuration = Double(equationText.count) * 0.045 + 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + readingDuration) { [weak self] in
            guard let self = self else { return }
            if self.state == .reading {
                self.state = .navigating
                // Don't announce anything - let user navigate
            }
        }
    }
    
    // MARK: - Exit Math Mode
    
    private func exitMathMode() {
        state = .inactive
        currentIndex = 0
        
        impactGenerator.impactOccurred(intensity: 0.5)
        onExitMathMode?()
        
        queueAnnouncement("Exited math mode")
    }
    
    // MARK: - Announcement Queue (Prevents Overlap)
    
    private func queueAnnouncement(_ text: String) {
        announcementQueue.append(text)
        processAnnouncementQueue()
    }
    
    private func processAnnouncementQueue() {
        guard !isAnnouncing, let announcement = announcementQueue.first else { return }
        
        isAnnouncing = true
        announcementQueue.removeFirst()
        
        // Small delay to ensure VoiceOver is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            UIAccessibility.post(notification: .announcement, argument: announcement)
            
            // Estimate announcement duration and mark as complete
            let duration = Double(announcement.count) * 0.045 + 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.isAnnouncing = false
                self?.processAnnouncementQueue()
            }
        }
    }
    
    // MARK: - Swipe Navigation (Accessibility Scroll)
    
    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        // Only handle swipes in exploring/navigating states
        guard state == .exploringReady || state == .navigating else {
            return false
        }
        
        state = .navigating
        
        switch direction {
        case .up:
            // Change to more detailed level
            changeLevelUp()
            return true
            
        case .down:
            // Change to less detailed level
            changeLevelDown()
            return true
            
        case .right:
            // Navigate to previous (swipe right = go back)
            navigatePrevious()
            return true
            
        case .left:
            // Navigate to next (swipe left = go forward)
            navigateNext()
            return true
            
        default:
            return false
        }
    }
    
    // MARK: - Level Navigation
    
    private func changeLevelUp() {
        currentLevel = currentLevel.next
        currentIndex = 0
        
        impactGenerator.impactOccurred(intensity: 0.7)
        queueAnnouncement("\(currentLevel.rawValue) level")
    }
    
    private func changeLevelDown() {
        currentLevel = currentLevel.previous
        currentIndex = 0
        
        impactGenerator.impactOccurred(intensity: 0.7)
        queueAnnouncement("\(currentLevel.rawValue) level")
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
            queueAnnouncement(parts[currentIndex])
        } else {
            impactGenerator.impactOccurred(intensity: 0.3)
            queueAnnouncement("End")
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
            queueAnnouncement(parts[currentIndex])
        } else {
            impactGenerator.impactOccurred(intensity: 0.3)
            queueAnnouncement("Beginning")
        }
    }
    
    private func getPartsForCurrentLevel() -> [String] {
        switch currentLevel {
        case .character:
            return navigationParts[0]
        case .symbol:
            return navigationParts[1]
        case .term:
            return navigationParts[2]
        case .structure:
            return navigationParts[3]
        }
    }
    
    // MARK: - Parse Equation for Navigation
    
    private func parseEquationForNavigation() {
        let text = fullEquationText
        guard !text.isEmpty && text != "equation" else {
            navigationParts = [["equation"], ["equation"], ["equation"], ["equation"]]
            return
        }
        
        // Character level: each character
        var characters: [String] = []
        for char in text where !char.isWhitespace && char != "," {
            characters.append(String(char))
        }
        
        // Symbol level: split by spaces, keep operators
        let symbolPattern = text.components(separatedBy: " ")
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Term level: split by commas (natural pauses)
        let terms = text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Structure level: identify major structures
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
        
        if structures.isEmpty {
            structures = [text]
        }
        
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
        
        // Remove prefixes
        let prefixes = ["Equation: ", "Equation:", "equation: ", "equation:", "Math: ", "Math:"]
        for prefix in prefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
            }
        }
        
        // Remove answer portions
        let answerPatterns = [
            #"[,.]?\s*(the\s+)?(sum|total|answer|result|area|volume|perimeter|value)\s+(is|are|=|equals)\s+[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?"#,
            #"\s+is\s+[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?$"#,
            #"\s*(=|equals)\s*[\d,\.]+\s*(square\s*)?(units|meters|feet|cm|mm|inches|m|ft)?\.?$"#
        ]
        
        for pattern in answerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }
        
        // Clean up
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        cleaned = cleaned.replacingOccurrences(of: ", ,", with: ",")
        cleaned = cleaned.replacingOccurrences(of: ",,", with: ",")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        while cleaned.hasSuffix(",") || cleaned.hasSuffix(";") {
            cleaned = String(cleaned.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        
        if cleaned.lowercased() == "equation" || cleaned.isEmpty {
            return ""
        }
        
        return cleaned
    }
    
    // MARK: - Escape Action (Exit Math Mode)
    
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
    
    func makeUIView(context: Context) -> MathCATAccessibilityContainer {
        let container = MathCATAccessibilityContainer()
        container.backgroundColor = .clear
        
        // Add WebView for visual rendering
        let webView = createMathWebView()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // Set initial values
        container.fullEquationText = fullSpokenText
        container.mathML = mathml ?? ""
        container.mathParts = mathParts
        container.onEnterMathMode = onEnterMathMode
        container.onExitMathMode = onExitMathMode
        
        return container
    }
    
    func updateUIView(_ container: MathCATAccessibilityContainer, context: Context) {
        container.fullEquationText = fullSpokenText
        container.mathML = mathml ?? ""
        container.mathParts = mathParts
        container.onEnterMathMode = onEnterMathMode
        container.onExitMathMode = onExitMathMode
        
        // Update WebView
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
        
        // CRITICAL: Hide from VoiceOver
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
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { pointer-events: none; }
                body { margin: 8px; font-family: -apple-system; font-size: 16px; background: transparent; }
            </style>
        </head>
        <body aria-hidden="true" inert>\(displayText)</body>
        </html>
        """
    }
    
    private func cleanMathML(_ mathml: String) -> String {
        var cleaned = mathml.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !cleaned.hasPrefix("<math") {
            cleaned = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\(cleaned)</math>"
        }
        
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
