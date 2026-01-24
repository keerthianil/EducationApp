//
//  SVGView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//
//  Renders SVG graphics using WKWebView
//  The parent SwiftUI view provides the single accessibility label for the entire graphic
//

import Foundation
import SwiftUI
import WebKit

struct SVGView: UIViewRepresentable {
    let svg: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        
        // CRITICAL: COMPLETELY disable accessibility on the WebView
        // This prevents VoiceOver from jumping to internal SVG elements
        // The parent SwiftUI view handles all accessibility
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        webView.accessibilityTraits = []
        
        // Also disable on scroll view
        webView.scrollView.isAccessibilityElement = false
        webView.scrollView.accessibilityElementsHidden = true
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Create HTML with aria-hidden to completely hide from screen readers
        // The parent SwiftUI view provides the single accessibility label
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta name="viewport" content="initial-scale=1, maximum-scale=1, user-scalable=no"/>
            <style>
                * {
                    -webkit-user-select: none;
                    user-select: none;
                    -webkit-touch-callout: none;
                }
                body {
                    margin: 0;
                    padding: 0;
                    background: #fff;
                }
                svg {
                    max-width: 100%;
                    height: auto;
                    display: block;
                }
                /* Remove all accessibility from SVG internals */
                svg * {
                    pointer-events: none;
                }
                /* Hide all interactive/focusable elements from accessibility */
                [tabindex], a, button, input, [role], [aria-label] {
                    pointer-events: none;
                    -webkit-user-select: none;
                }
            </style>
        </head>
        <body aria-hidden="true" role="presentation" tabindex="-1" inert>
            <div aria-hidden="true" role="presentation" inert>
                \(sanitizeSVG(svg))
            </div>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        
        // CRITICAL: Ensure WebView accessibility is COMPLETELY disabled after load
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        webView.accessibilityTraits = []
        
        // Also disable accessibility on scroll view
        webView.scrollView.isAccessibilityElement = false
        webView.scrollView.accessibilityElementsHidden = true
    }
    
    /// Sanitize SVG to remove any accessibility attributes that might cause jumping
    private func sanitizeSVG(_ svg: String) -> String {
        var result = svg
        
        // Remove aria attributes that might cause VoiceOver to find elements
        let ariaPattern = #"\s*aria-[a-z]+="[^"]*""#
        if let regex = try? NSRegularExpression(pattern: ariaPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        // Remove role attributes
        let rolePattern = #"\s*role="[^"]*""#
        if let regex = try? NSRegularExpression(pattern: rolePattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        // Remove tabindex attributes
        let tabPattern = #"\s*tabindex="[^"]*""#
        if let regex = try? NSRegularExpression(pattern: tabPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        // Add aria-hidden to the SVG root if not present
        if !result.contains("aria-hidden") {
            result = result.replacingOccurrences(of: "<svg", with: "<svg aria-hidden=\"true\"", options: .caseInsensitive)
        }
        
        return result
    }
}

// MARK: - Alternative: UIKit-based SVG View for complete accessibility control

/// A UIKit wrapper that ensures the WebView is completely invisible to VoiceOver
class AccessibilityHiddenSVGView: UIView {
    private var webView: WKWebView?
    
    var svg: String = "" {
        didSet {
            loadSVG()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupWebView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWebView()
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: bounds, configuration: config)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // COMPLETELY hide from accessibility
        wv.isAccessibilityElement = false
        wv.accessibilityElementsHidden = true
        wv.scrollView.isAccessibilityElement = false
        wv.scrollView.accessibilityElementsHidden = true
        
        addSubview(wv)
        self.webView = wv
        
        // Hide self from accessibility too - parent view handles it
        self.isAccessibilityElement = false
        self.accessibilityElementsHidden = true
    }
    
    private func loadSVG() {
        guard let webView = webView else { return }
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="initial-scale=1, maximum-scale=1, user-scalable=no"/>
            <style>
                * { -webkit-user-select: none; pointer-events: none; }
                body { margin: 0; padding: 0; background: #fff; }
                svg { max-width: 100%; height: auto; display: block; }
            </style>
        </head>
        <body aria-hidden="true" inert>\(svg)</body>
        </html>
        """
        
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    override var accessibilityElementsHidden: Bool {
        get { true }
        set { /* Always hidden */ }
    }
}
