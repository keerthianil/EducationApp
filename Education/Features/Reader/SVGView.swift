//
//  SVGView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import SwiftUI
import WebKit

struct SVGView: UIViewRepresentable {
    let svg: String

    func makeUIView(context: Context) -> WKWebView { WKWebView() }
    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <html><head><meta name="viewport" content="initial-scale=1, maximum-scale=1"/></head>
        <body style="margin:0;background:#fff;">\(svg)</body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.accessibilityLabel = "Graphic"
        webView.accessibilityHint = "Use swipe to move to description."
    }
}
