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
        
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        webView.accessibilityTraits = []
        
        webView.scrollView.isAccessibilityElement = false
        webView.scrollView.accessibilityElementsHidden = true
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
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
                svg * {
                    pointer-events: none;
                }
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
        
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        webView.accessibilityTraits = []
        
        webView.scrollView.isAccessibilityElement = false
        webView.scrollView.accessibilityElementsHidden = true
    }
    
    private func sanitizeSVG(_ svg: String) -> String {
        var result = svg
        
        let ariaPattern = #"\s*aria-[a-z]+="[^"]*""#
        if let regex = try? NSRegularExpression(pattern: ariaPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        let rolePattern = #"\s*role="[^"]*""#
        if let regex = try? NSRegularExpression(pattern: rolePattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        let tabPattern = #"\s*tabindex="[^"]*""#
        if let regex = try? NSRegularExpression(pattern: tabPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: "")
        }
        
        if !result.contains("aria-hidden") {
            result = result.replacingOccurrences(of: "<svg", with: "<svg aria-hidden=\"true\"", options: .caseInsensitive)
        }
        
        return result
    }
}

// MARK: - Alternative: UIKit-based SVG View

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
        
        wv.isAccessibilityElement = false
        wv.accessibilityElementsHidden = true
        wv.scrollView.isAccessibilityElement = false
        wv.scrollView.accessibilityElementsHidden = true
        
        addSubview(wv)
        self.webView = wv
        
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