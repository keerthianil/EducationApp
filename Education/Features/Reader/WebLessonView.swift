//
//  WebLessonView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import SwiftUI
import WebKit

struct WebLessonView: UIViewRepresentable {
    /// Pass the file name WITHOUT .html, e.g. "area-of-compound-figures"
    let htmlFileName: String

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.defaultWebpagePreferences.allowsContentJavaScript = true

        let web = WKWebView(frame: .zero, configuration: cfg)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.isScrollEnabled = true
        web.scrollView.showsVerticalScrollIndicator = true
        web.scrollView.alwaysBounceVertical = true

        // Make sure we always render LIGHT like Figma
        if #available(iOS 13.0, *) { web.overrideUserInterfaceStyle = .light }

        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard
            let url = Bundle.main.url(forResource: htmlFileName, withExtension: "html"),
            let original = try? String(contentsOf: url, encoding: .utf8)
        else {
            web.loadHTMLString("<html><body><p>Missing \(htmlFileName).html in bundle.</p></body></html>", baseURL: nil)
            return
        }

        // A light-mode wrapper with accessible defaults + MathJax for equations
        let wrapped = """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <meta name="color-scheme" content="light">
          <style>
            :root { color-scheme: light; }
            html, body { margin:0; padding:16px; background:#F5F5F5; color:#212121;
                         font-family:-apple-system, system-ui, 'Inter', Arial, sans-serif; line-height:1.5; }
            h1,h2,h3,h4,h5 { color:#212121; }
            a { color:#214F9A; }
            img, svg { max-width:100%; height:auto; }
            mjx-container { outline:none; }
            body { -webkit-text-size-adjust: 100%; }
          </style>
          <!-- MathJax: converts LaTeX/MathML to accessible math VO can traverse -->
          <script id="MathJax-script" async
            src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js">
          </script>
        </head>
        <body>
          \(original)
        </body>
        </html>
        """
        web.loadHTMLString(wrapped, baseURL: nil)
    }
}
