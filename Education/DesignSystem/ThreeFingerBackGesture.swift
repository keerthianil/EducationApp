//
//  ThreeFingerBackGesture.swift
//  Education
//
//
//  Provides 3-finger swipe right gesture for back navigation
//  Works in both normal mode and VoiceOver mode
//

import SwiftUI
import UIKit

// MARK: - Three Finger Swipe Container

struct ThreeFingerSwipeContainer<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let onSwipeBack: () -> Void
    
    func makeUIViewController(context: Context) -> ThreeFingerSwipeHostingController {
        let vc = ThreeFingerSwipeHostingController(onSwipeBack: onSwipeBack)
        vc.setContent(content)
        return vc
    }
    
    func updateUIViewController(_ uiViewController: ThreeFingerSwipeHostingController, context: Context) {
        uiViewController.setContent(content)
        uiViewController.onSwipeBack = onSwipeBack
    }
}

// MARK: - Custom Accessible View for VoiceOver 3-finger swipe

class AccessibleSwipeBackView: UIView {
    var onSwipeBack: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAccessibility()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupAccessibility()
    }
    
    private func setupAccessibility() {
        isAccessibilityElement = false
        accessibilityViewIsModal = false
    }
    
    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        if direction == .right {
            // 3-finger swipe RIGHT in VoiceOver = go back
            onSwipeBack?()
            UIAccessibility.post(notification: .announcement, argument: "Going back")
            return true
        }
        // Let other scroll directions pass through to scroll content
        return super.accessibilityScroll(direction)
    }
    
    // 2-finger Z-scrub escape gesture
    override func accessibilityPerformEscape() -> Bool {
        onSwipeBack?()
        return true
    }
}

// MARK: - Hosting Controller

class ThreeFingerSwipeHostingController: UIViewController, UIGestureRecognizerDelegate {
    var onSwipeBack: () -> Void
    private var hostingController: UIHostingController<AnyView>?
    private var accessibleOverlay: AccessibleSwipeBackView?
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    init(onSwipeBack: @escaping () -> Void) {
        self.onSwipeBack = onSwipeBack
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setContent<Content: View>(_ content: Content) {
        let newRootView = AnyView(content)
        
        if let hc = hostingController {
            // Update rootView only — do NOT replace the hosting controller
            // Replacing it on every SwiftUI update caused teardown/rebuild loop (document ↔ dashboard flicker)
            hc.rootView = newRootView
        } else {
            // First time: add hosting controller
            let hc = UIHostingController(rootView: newRootView)
            hc.view.backgroundColor = .clear
            addChild(hc)
            hc.view.frame = view.bounds
            hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(hc.view)
            hc.didMove(toParent: self)
            hostingController = hc
            
            if let overlay = accessibleOverlay {
                view.bringSubviewToFront(overlay)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupGestures()
        setupAccessibleOverlay()
        hapticGenerator.prepare()
    }
    
    private func setupAccessibleOverlay() {
        // Add invisible overlay that captures VoiceOver gestures
        let overlay = AccessibleSwipeBackView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false // Don't block normal touches
        overlay.onSwipeBack = { [weak self] in
            self?.hapticGenerator.impactOccurred(intensity: 0.8)
            self?.onSwipeBack()
        }
        view.addSubview(overlay)
        accessibleOverlay = overlay
    }
    
    private func setupGestures() {
        // 3-finger swipe RIGHT only — no 2-finger backup to avoid conflict with Next/Prev taps and two-finger scroll
        let threeFingerSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeBack))
        threeFingerSwipe.direction = .right
        threeFingerSwipe.numberOfTouchesRequired = 3
        threeFingerSwipe.delegate = self
        view.addGestureRecognizer(threeFingerSwipe)
    }
    
    @objc private func handleSwipeBack(_ gesture: UISwipeGestureRecognizer) {
        if gesture.state == .recognized {
            hapticGenerator.impactOccurred(intensity: 0.8)
            onSwipeBack()
        }
    }
    
    // MARK: - Accessibility for VoiceOver
    
    // Handle 3-finger swipe in VoiceOver at view controller level
    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        if direction == .right {
            hapticGenerator.impactOccurred(intensity: 0.8)
            onSwipeBack()
            UIAccessibility.post(notification: .announcement, argument: "Going back")
            return true
        }
        return false
    }
    
    // Handle 2-finger Z-scrub escape
    override func accessibilityPerformEscape() -> Bool {
        hapticGenerator.impactOccurred(intensity: 0.8)
        onSwipeBack()
        return true
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Don't capture touches that start on buttons/controls — avoids accidental dismiss when tapping Next/Prev
        var v: UIView? = touch.view
        while let view = v {
            if view is UIControl { return false }
            v = view.superview
        }
        return true
    }
}

// MARK: - View Modifier

struct ThreeFingerSwipeBackModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        ThreeFingerSwipeContainer(content: content, onSwipeBack: action)
            .ignoresSafeArea()
    }
}

// MARK: - View Extension

extension View {
   
    func onThreeFingerSwipeBack(perform action: @escaping () -> Void) -> some View {
        self.modifier(ThreeFingerSwipeBackModifier(action: action))
    }
}

// MARK: - Preview

#if DEBUG
struct ThreeFingerBackGesture_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(0..<20, id: \.self) { i in
                        Text("Item \(i)")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("Test View")
            .onThreeFingerSwipeBack {
                print("3-finger swipe back triggered!")
            }
        }
    }
}
#endif
