//
//  MathAccessibilityElement.swift
//  Education
//
//  Math accessibility:
//    1. Inline: "Math equation. [text]. Double tap to explore"
//    2. Tap/double-tap → full-screen view (equation fills screen)
//    3. VO announces equation + short instructions on entry
//    4. Custom rotor "Equation parts" works ANYWHERE on screen
//    5. Back button + 3-finger swipe + 2-finger scrub to exit
//    6. No visible text/heading — clean screen, just the equation
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

// MARK: - MathCATView  (inline equation — tap opens explorer)

struct MathCATView: View {
    let mathml: String?
    let latex: String?
    let fullSpokenText: String
    let mathParts: [MathPart]
    let displayType: String?
    var onEnterMathMode: (() -> Void)?
    var onExitMathMode: (() -> Void)?

    @State private var showExploration = false

    private func openExploration() {
        onEnterMathMode?()
        InteractionLogger.shared.log(
            event: .mathModeEnter, objectType: .mathEquation,
            label: "Open Math Exploration", location: .zero,
            additionalInfo: String(fullSpokenText.prefix(80))
        )
        showExploration = true
    }

    var body: some View {
        ZStack {
            MathMLInlineRenderer(mathml: mathml, latex: latex, displayType: displayType)
                .allowsHitTesting(false)

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { openExploration() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Math equation")
        .accessibilityHint("Double tap to enter math mode")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) { openExploration() }
        .fullScreenCover(isPresented: $showExploration) {
            MathExplorationView(
                mathml: mathml, latex: latex,
                fullSpokenText: fullSpokenText,
                onDismiss: {
                    showExploration = false
                    onExitMathMode?()
                    InteractionLogger.shared.log(event: .mathModeExit, objectType: .mathEquation, label: "Closed Math Exploration", location: .zero)
                }
            )
        }
    }
}

// MARK: - MathMLInlineRenderer  (visual only)

struct MathMLInlineRenderer: UIViewRepresentable {
    let mathml: String?
    let latex: String?
    let displayType: String?

    func makeUIView(context: Context) -> WKWebView {
        let w = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        w.isOpaque = false; w.backgroundColor = .clear
        w.scrollView.isScrollEnabled = false
        w.isUserInteractionEnabled = false
        w.isAccessibilityElement = false
        w.accessibilityElementsHidden = true
        loadHTML(w)
        return w
    }

    func updateUIView(_ w: WKWebView, context: Context) { loadHTML(w) }

    private func loadHTML(_ w: WKWebView) {
        guard let ml = mathml, !ml.isEmpty else {
            w.loadHTMLString("<!DOCTYPE html><html><head><meta name=\"viewport\" content=\"width=device-width,initial-scale=1.0\"><style>body{margin:8px;font-size:16px;background:transparent}</style></head><body>\(latex ?? "")</body></html>", baseURL: nil)
            return
        }
        let clean = cleanML(ml)
        let isBlock = displayType?.lowercased() == "block" || displayType?.lowercased() == "display"
        let st = isBlock ? "display:block;margin:12px 0;" : "display:inline-block;"
        w.loadHTMLString("<!DOCTYPE html><html><head><meta charset=\"UTF-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1.0,maximum-scale=1.0\"><style>*{-webkit-user-select:none}body{margin:0;padding:8px;background:transparent}math{\(st)font-size:18px;color:#121417}</style></head><body>\(clean)</body></html>", baseURL: nil)
    }

    private func cleanML(_ ml: String) -> String {
        var c = ml.trimmingCharacters(in: .whitespacesAndNewlines)
        if !c.hasPrefix("<math") {
            if let s = c.range(of: "<math", options: .caseInsensitive),
               let e = c.range(of: "</math>", options: [.caseInsensitive, .backwards]) {
                c = String(c[s.lowerBound..<e.upperBound])
            } else { c = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\(c)</math>" }
        }
        if !c.contains("xmlns="), let r = c.range(of: "<math", options: .caseInsensitive) {
            c = c.replacingCharacters(in: r, with: "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"")
        }
        return c
    }
}

// MARK: - MathExplorationView  (full screen — no visible text)

struct MathExplorationView: View {
    let mathml: String?
    let latex: String?
    let fullSpokenText: String
    let onDismiss: () -> Void

    var body: some View {
        // The full-screen rotor UIView is the ENTIRE background.
        // This ensures swipe up/down works no matter where the user touches.
        ZStack {
            // Full-screen rotor element (handles all VO interaction)
            MathFullScreenRotorView(
                fullSpokenText: fullSpokenText,
                onDismiss: onDismiss
            )
            .ignoresSafeArea()

            // Visual equation centered on screen (not interactive, not accessible)
            VStack {
                Spacer()
                MathMLLargeRenderer(mathml: mathml, latex: latex)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .accessibilityHidden(true)
                Spacer()
            }

            // Back button (top-left, above everything)
            VStack {
                HStack {
                    Button {
                        onDismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Back")
                                .font(.custom("Arial", size: 17))
                        }
                        .foregroundColor(ColorTokens.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .accessibilityLabel("Back")
                    .accessibilityHint("Return to document")
                    Spacer()
                }
                .padding(.top, 8)
                Spacer()
            }
        }
        .background(Color.white)
        .onThreeFingerSwipeBack { onDismiss() }
        .accessibilityAction(.escape) { onDismiss() }
        .onAppear {
            if UIAccessibility.isVoiceOverRunning {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    let msg = "Math mode. Double tap to hear the equation. Use Equation Parts rotor and swipe up or down to navigate. Two finger scrub to go back."
                    UIAccessibility.post(notification: .announcement, argument: msg)
                }
            }
        }
    }
}

// MARK: - MathMLLargeRenderer  (large visual equation — fills available space)

struct MathMLLargeRenderer: UIViewRepresentable {
    let mathml: String?
    let latex: String?

    func makeUIView(context: Context) -> WKWebView {
        let w = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        w.isOpaque = false; w.backgroundColor = .clear
        w.scrollView.isScrollEnabled = false
        w.isUserInteractionEnabled = false
        w.isAccessibilityElement = false
        w.accessibilityElementsHidden = true
        loadHTML(w)
        return w
    }

    func updateUIView(_ w: WKWebView, context: Context) { loadHTML(w) }

    private func loadHTML(_ w: WKWebView) {
        guard let ml = mathml, !ml.isEmpty else {
            let html = """
            <!DOCTYPE html><html><head>
            <meta name="viewport" content="width=device-width,initial-scale=1.0">
            <style>
            body{margin:0;padding:20px;display:flex;align-items:center;justify-content:center;min-height:100vh;background:transparent;box-sizing:border-box}
            .eq{font-size:64px;color:#121417;text-align:center}
            </style>
            <script>
            window.onload = function() {
                var e = document.querySelector('.eq');
                if (!e) return;
                var cw = document.body.clientWidth * 0.92;
                var sizes = [64, 56, 48, 40, 36, 32, 28, 24, 20];
                for (var i = 0; i < sizes.length; i++) {
                    e.style.fontSize = sizes[i] + 'px';
                    if (e.scrollWidth <= cw) break;
                }
            };
            </script>
            </head>
            <body><div class="eq">\(latex ?? "")</div></body></html>
            """
            w.loadHTMLString(html, baseURL: nil)
            return
        }

        var clean = ml.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.hasPrefix("<math") {
            if let s = clean.range(of: "<math", options: .caseInsensitive),
               let e = clean.range(of: "</math>", options: [.caseInsensitive, .backwards]) {
                clean = String(clean[s.lowerBound..<e.upperBound])
            } else { clean = "<math xmlns=\"http://www.w3.org/1998/Math/MathML\">\(clean)</math>" }
        }
        if !clean.contains("xmlns="), let r = clean.range(of: "<math", options: .caseInsensitive) {
            clean = clean.replacingCharacters(in: r, with: "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"")
        }

        let html = """
        <!DOCTYPE html><html><head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0">
        <style>
        *{-webkit-user-select:none}
        html,body{margin:0;padding:0;width:100%;height:100%;display:flex;align-items:center;justify-content:center;background:transparent;overflow:hidden}
        math{display:block;font-size:64px;color:#121417;max-width:95vw;padding:16px;transform-origin:center center}
        </style>
        <script>
        window.onload = function() {
            var m = document.querySelector('math');
            if (!m) return;
            var cw = document.body.clientWidth * 0.92;
            var ch = document.body.clientHeight * 0.7;
            var sizes = [64, 56, 48, 40, 36, 32, 28, 24, 20];
            for (var i = 0; i < sizes.length; i++) {
                m.style.fontSize = sizes[i] + 'px';
                if (m.scrollWidth <= cw && m.scrollHeight <= ch) break;
            }
        };
        </script>
        </head>
        <body>\(clean)</body></html>
        """
        w.loadHTMLString(html, baseURL: nil)
    }
}

// MARK: - MathFullScreenRotorView (fills entire screen — rotor works everywhere)

struct MathFullScreenRotorView: UIViewRepresentable {
    let fullSpokenText: String
    let onDismiss: () -> Void

    func makeUIView(context: Context) -> MathFullScreenRotorUIView {
        let v = MathFullScreenRotorUIView()
        v.fullEquationText = fullSpokenText
        v.onDismiss = onDismiss
        v.buildParts()
        return v
    }

    func updateUIView(_ v: MathFullScreenRotorUIView, context: Context) {
        v.fullEquationText = fullSpokenText
        v.onDismiss = onDismiss
        v.buildParts()
    }
}

class MathFullScreenRotorUIView: UIView {
    var fullEquationText: String = "equation"
    var onDismiss: (() -> Void)?

    private var parts: [String] = []
    private var currentIndex: Int = 0
    private let impact = UIImpactFeedbackGenerator(style: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityTraits = .staticText
        backgroundColor = .clear
        impact.prepare()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Accessibility

    override var accessibilityLabel: String? {
        get { "Math mode" }
        set {}
    }

    override var accessibilityHint: String? {
        get { "Double tap to hear equation. Use Equation Parts rotor and swipe up or down." }
        set {}
    }

    // MARK: - Custom Rotor

    override var accessibilityCustomRotors: [UIAccessibilityCustomRotor]? {
        get { [makeRotor()] }
        set {}
    }

    private func makeRotor() -> UIAccessibilityCustomRotor {
        UIAccessibilityCustomRotor(name: "Equation parts") { [weak self] predicate in
            guard let self = self, !self.parts.isEmpty else { return nil }

            if predicate.searchDirection == .next {
                if self.currentIndex < self.parts.count - 1 {
                    self.currentIndex += 1
                    self.impact.impactOccurred(intensity: 0.5)
                } else {
                    self.impact.impactOccurred(intensity: 0.3)
                    self.announce("End of equation")
                    return UIAccessibilityCustomRotorItemResult(targetElement: self, targetRange: nil)
                }
            } else {
                if self.currentIndex > 0 {
                    self.currentIndex -= 1
                    self.impact.impactOccurred(intensity: 0.5)
                } else {
                    self.impact.impactOccurred(intensity: 0.3)
                    self.announce("Beginning of equation")
                    return UIAccessibilityCustomRotorItemResult(targetElement: self, targetRange: nil)
                }
            }

            let part = self.parts[self.currentIndex]
            let pos = "\(self.currentIndex + 1) of \(self.parts.count)"
            self.announce("\(part). \(pos)")

            InteractionLogger.shared.log(
                event: .mathNavigate, objectType: .mathEquation,
                label: part, location: .zero,
                additionalInfo: "Part \(pos)"
            )

            return UIAccessibilityCustomRotorItemResult(targetElement: self, targetRange: nil)
        }
    }

    // MARK: - Double Tap → Read Full Equation

    override func accessibilityActivate() -> Bool {
        impact.impactOccurred(intensity: 0.8)
        InteractionLogger.shared.log(
            event: .doubleTap, objectType: .mathEquation,
            label: "Read Equation", location: .zero,
            additionalInfo: String(fullEquationText.prefix(80))
        )
        announce(fullEquationText)
        return true
    }

    // MARK: - Escape

    override func accessibilityPerformEscape() -> Bool {
        onDismiss?()
        return true
    }

    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        return false // let 3-finger swipe pass through
    }

    // MARK: - Parts

    func buildParts() {
        let text = fullEquationText
        guard !text.isEmpty && text != "equation" else { parts = ["equation"]; return }
        let p = text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        parts = p.isEmpty ? [text] : p
        currentIndex = 0
    }

    private func announce(_ text: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            UIAccessibility.post(notification: .announcement, argument: text)
        }
    }
}
