//
//  TactileTouchOverlay.swift
//  Education
//
//  UIKit bridge for continuous touch tracking

import SwiftUI
import UIKit

struct TactileTouchOverlay: UIViewRepresentable {
    let viewBox: CGRect
    @Binding var canvasSize: CGSize
    let onTouch: (CGPoint) -> Void
    let onDrag: (CGPoint, CGPoint) -> Void
    let onEnd: () -> Void
    
    func makeUIView(context: Context) -> TouchTrackingView {
        let view = TouchTrackingView()
        view.viewBox = viewBox
        view.canvasSize = canvasSize
        view.onTouch = onTouch
        view.onDrag = onDrag
        view.onEnd = onEnd
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        return view
    }
    
    func updateUIView(_ view: TouchTrackingView, context: Context) {
        view.viewBox = viewBox
        view.canvasSize = canvasSize
        view.onTouch = onTouch
        view.onDrag = onDrag
        view.onEnd = onEnd
    }
}

class TouchTrackingView: UIView {
    var viewBox: CGRect = .zero
    var canvasSize: CGSize = .zero
    var onTouch: ((CGPoint) -> Void)?
    var onDrag: ((CGPoint, CGPoint) -> Void)?
    var onEnd: (() -> Void)?
    private var lastLocation: CGPoint?
    private var isTracking = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        backgroundColor = .clear
        isMultipleTouchEnabled = false
        isExclusiveTouch = false
        // Critical: Allow touches even when VoiceOver is on
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        // Ensure we can receive touches with VoiceOver
        accessibilityTraits = []
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Always return self to ensure we receive touches
        if self.bounds.contains(point) {
            return self
        }
        return nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        
        // Ignore double-tap (let SwiftUI gesture handle it)
        if touch.tapCount >= 2 {
            return
        }

        // Process single tap immediately
        let location = touch.location(in: self)
        lastLocation = location
        isTracking = true
        
        #if DEBUG
        print("[TouchOverlay] touchesBegan at: \(location), VoiceOver: \(UIAccessibility.isVoiceOverRunning)")
        #endif
        
        // Call on main thread immediately - don't delay with VoiceOver
        // VoiceOver can suppress touches if we delay
        if Thread.isMainThread {
            self.onTouch?(location)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onTouch?(location)
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isTracking,
              let touch = touches.first else { return }
        
        let current = touch.location(in: self)
        
        if let last = lastLocation {
            // Call immediately on main thread - don't delay with VoiceOver
            if Thread.isMainThread {
                self.onDrag?(last, current)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.onDrag?(last, current)
                }
            }
        }
        lastLocation = current
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTracking = false
        lastLocation = nil
        
        // Call on main thread
        DispatchQueue.main.async { [weak self] in
            self?.onEnd?()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isTracking = false
        lastLocation = nil
        
        // Call on main thread
        DispatchQueue.main.async { [weak self] in
            self?.onEnd?()
        }
    }
}