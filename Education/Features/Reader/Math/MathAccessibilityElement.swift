//
//  MathAccessibilityElement.swift
//  Education
//
//  In-place math mode (NO screen change):
//    1. VO: "Math equation. Double tap to enter math mode"
//    2. Double-tap → "Math mode. [instructions]" 
//    3. Custom rotor "Equation parts" — swipe up/down navigates
//    4. Double-tap again → reads full equation
//    5. Two-finger scrub → exits math mode back to normal
//

import UIKit
import SwiftUI
import WebKit

// MARK: - Supporting Types

struct MathPart {
    let text: String
    let level: MathNavigationLevel
    let children: [MathPart]
    init(text: String, level: MathNavigationLevel = .term, children: [MathPart] = []) {
        self.text = text; self.level = level; self.children = children
    }
}

enum MathNavigationLevel: String, CaseIterable {
    case character = "Character"
    case symbol    = "Symbol"
    case term      = "Term"
    case structure = "Structure"
}

enum MathComplexity {
    static func isSubstantial(latex: String?, mathml: String?) -> Bool {
        guard let l = latex, !l.isEmpty else { return false }
        let ops = ["+", "=", "\\frac", "\\sqrt", "^{", "\\times", "\\cdot"]
        return ops.filter { l.contains($0) }.count >= 2
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - MathCATView  (SwiftUI wrapper — in-place math mode)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

struct MathCATView: UIViewRepresentable {
    let mathml: String?
    let latex: String?
    let fullSpokenText: String
    let mathParts: [MathPart]
    let displayType: String?
    var onEnterMathMode: (() -> Void)?
    var onExitMathMode: (() -> Void)?

    func makeUIView(context: Context) -> MathInPlaceContainer {
        let c = MathInPlaceContainer()
        c.backgroundColor = .clear

        // Add WKWebView for visual rendering
        let w = makeWebView()
        w.translatesAutoresizingMaskIntoConstraints = false
        c.addSubview(w)
        NSLayoutConstraint.activate([
            w.topAnchor.constraint(equalTo: c.topAnchor),
            w.leadingAnchor.constraint(equalTo: c.leadingAnchor),
            w.trailingAnchor.constraint(equalTo: c.trailingAnchor),
            w.bottomAnchor.constraint(equalTo: c.bottomAnchor),
        ])

        apply(to: c)
        return c
    }

    func updateUIView(_ c: MathInPlaceContainer, context: Context) {
        apply(to: c)
        if let w = c.subviews.first(where: { $0 is WKWebView }) as? WKWebView {
            loadHTML(into: w)
        }
    }

    private func apply(to c: MathInPlaceContainer) {
        c.fullEquationText = fullSpokenText
        c.onEnterMathMode = onEnterMathMode
        c.onExitMathMode = onExitMathMode
        c.buildParts()
    }

    private func makeWebView() -> WKWebView {
        let w = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        w.isOpaque = false
        w.backgroundColor = .clear
        w.scrollView.isScrollEnabled = false
        w.isUserInteractionEnabled = false
        w.isAccessibilityElement = false
        w.accessibilityElementsHidden = true
        loadHTML(into: w)
        return w
    }

    private func loadHTML(into w: WKWebView) {
        guard let ml = mathml, !ml.isEmpty else {
            w.loadHTMLString("""
            <!DOCTYPE html><html><head>
            <meta name="viewport" content="width=device-width,initial-scale=1.0">
            <style>body{margin:8px;font-size:16px;background:transparent}</style>
            </head><body>\(latex ?? "")</body></html>
            """, baseURL: nil)
            return
        }
        let clean = cleanML(ml)
        let isBlock = displayType?.lowercased() == "block" || displayType?.lowercased() == "display"
        let style = isBlock ? "display:block;margin:12px 0;" : "display:inline-block;"
        w.loadHTMLString("""
        <!DOCTYPE html><html><head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0">
        <style>
        *{-webkit-user-select:none}
        body{margin:0;padding:8px;background:transparent}
        math{\(style)font-size:18px;color:#121417}
        </style></head>
        <body>\(clean)</body></html>
        """, baseURL: nil)
    }

    private func cleanML(_ ml: String) -> String {
        var c = ml.trimmingCharacters(in: .whitespacesAndNewlines)
        if !c.hasPrefix("<math") {
            if let s = c.range(of: "<math", options: .caseInsensitive),
               let e = c.range(of: "</math>", options: [.caseInsensitive, .backwards]) {
                c = String(c[s.lowerBound..<e.upperBound])
            } else {
                c = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\(c)</math>"
            }
        }
        if !c.contains("xmlns="), let r = c.range(of: "<math", options: .caseInsensitive) {
            c = c.replacingCharacters(in: r, with: "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"")
        }
        return c
    }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MARK: - MathInPlaceContainer  (UIView — all VO logic happens here)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class MathInPlaceContainer: UIView {

    var fullEquationText: String = "equation"
    var onEnterMathMode: (() -> Void)?
    var onExitMathMode: (() -> Void)?

    // State
    private enum MathState { case inactive, mathMode }
    private var state: MathState = .inactive

    // Parts for rotor
    private var parts: [String] = []
    private var currentIndex: Int = 0

    // Haptics
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let selection = UISelectionFeedbackGenerator()

    // Announcement queue
    private var isAnnouncing = false
    private var announceQueue: [String] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        impact.prepare()
        selection.prepare()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Accessibility Label / Hint

    override var accessibilityLabel: String? {
        get {
            switch state {
            case .inactive:
                return "Math equation"
            case .mathMode:
                if currentIndex < parts.count {
                    return "Part \(currentIndex + 1) of \(parts.count): \(parts[currentIndex])"
                }
                return "Math mode"
            }
        }
        set {}
    }

    override var accessibilityHint: String? {
        get {
            switch state {
            case .inactive:
                return "Double tap to enter math mode"
            case .mathMode:
                return "Double tap to hear full equation. Two finger scrub to exit."
            }
        }
        set {}
    }

    // MARK: - Custom Rotor (only active in math mode)

    override var accessibilityCustomRotors: [UIAccessibilityCustomRotor]? {
        get {
            guard state == .mathMode else { return nil }
            return [equationPartsRotor()]
        }
        set {}
    }

    private func equationPartsRotor() -> UIAccessibilityCustomRotor {
        UIAccessibilityCustomRotor(name: "Equation parts") { [weak self] predicate in
            guard let self = self, !self.parts.isEmpty else { return nil }

            if predicate.searchDirection == .next {
                if self.currentIndex < self.parts.count - 1 {
                    self.currentIndex += 1
                    self.selection.selectionChanged()
                } else {
                    self.impact.impactOccurred(intensity: 0.3)
                    self.queueAnnounce("End of equation")
                    return UIAccessibilityCustomRotorItemResult(targetElement: self, targetRange: nil)
                }
            } else {
                if self.currentIndex > 0 {
                    self.currentIndex -= 1
                    self.selection.selectionChanged()
                } else {
                    self.impact.impactOccurred(intensity: 0.3)
                    self.queueAnnounce("Beginning of equation")
                    return UIAccessibilityCustomRotorItemResult(targetElement: self, targetRange: nil)
                }
            }

            let part = self.parts[self.currentIndex]
            let pos = "\(self.currentIndex + 1) of \(self.parts.count)"
            self.queueAnnounce("\(part). \(pos)")

            InteractionLogger.shared.log(
                event: .mathNavigate, objectType: .mathEquation,
                label: part, location: .zero,
                additionalInfo: "Part \(pos)"
            )

            return UIAccessibilityCustomRotorItemResult(targetElement: self, targetRange: nil)
        }
    }

    // MARK: - Double Tap

    override func accessibilityActivate() -> Bool {
        switch state {
        case .inactive:
            enterMathMode()
            return true
        case .mathMode:
            readFullEquation()
            return true
        }
    }

    // MARK: - Enter Math Mode (in-place, no screen change)

    private func enterMathMode() {
        state = .mathMode
        currentIndex = 0
        impact.impactOccurred(intensity: 1.0)
        onEnterMathMode?()

        InteractionLogger.shared.log(
            event: .mathModeEnter, objectType: .mathEquation,
            label: "Math Mode Entered", location: .zero
        )

        // CRITICAL: Tell UIKit to re-read accessibilityCustomRotors.
        // Without this, the rotor we return from the computed property
        // won't appear because UIKit cached the old nil value.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            UIAccessibility.post(notification: .layoutChanged, argument: self)
        }

        queueAnnounce("Math mode. Double tap to hear the equation. Use Equation Parts rotor and swipe up or down to navigate. Two finger scrub to exit.")
    }

    // MARK: - Read Full Equation

    private func readFullEquation() {
        impact.impactOccurred(intensity: 0.8)
        announceQueue.removeAll()
        isAnnouncing = false

        InteractionLogger.shared.log(
            event: .doubleTap, objectType: .mathEquation,
            label: "Read Equation", location: .zero,
            additionalInfo: String(fullEquationText.prefix(80))
        )

        queueAnnounce(fullEquationText)
    }

    // MARK: - Exit Math Mode

    private func exitMathMode() {
        state = .inactive
        currentIndex = 0
        impact.impactOccurred(intensity: 0.5)
        onExitMathMode?()
        announceQueue.removeAll()
        isAnnouncing = false

        InteractionLogger.shared.log(
            event: .mathModeExit, objectType: .mathEquation,
            label: "Exited Math Mode", location: .zero
        )

        // Tell UIKit rotors changed (removes "Equation parts" from rotor)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            UIAccessibility.post(notification: .layoutChanged, argument: self)
        }

        queueAnnounce("Exited math mode")
    }

    // MARK: - Escape (two-finger scrub)

    override func accessibilityPerformEscape() -> Bool {
        if state == .mathMode {
            exitMathMode()
            return true
        }
        return false
    }

    // Pass 3-finger swipe through for back navigation
    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        return false
    }

    // MARK: - Build Parts

    func buildParts() {
        let text = fullEquationText
        guard !text.isEmpty && text != "equation" else {
            parts = ["equation"]; return
        }
        let p = text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        parts = p.isEmpty ? [text] : p
        currentIndex = 0
    }

    // MARK: - Announcement Queue

    private func queueAnnounce(_ text: String) {
        announceQueue.append(text)
        processQueue()
    }

    private func processQueue() {
        guard !isAnnouncing, let text = announceQueue.first else { return }
        isAnnouncing = true
        announceQueue.removeFirst()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            UIAccessibility.post(notification: .announcement, argument: text)
            let delay = max(0.4, Double(text.count) * 0.04)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.isAnnouncing = false
                self?.processQueue()
            }
        }
    }
}
