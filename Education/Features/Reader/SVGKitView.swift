//
//  SVGKitView.swift
//  Education
//
//  SVG rendering using SVGKit library
//  Provides native SVG rendering without manual parsing
//

import SwiftUI
import UIKit
import WebKit
import ObjectiveC

// SVGKit import - will be available when package is properly linked
#if canImport(SVGKit)
import SVGKit
#endif

// MARK: - SVGKit Wrapper View
// Note: Add SVGKit via Swift Package Manager:
// URL: https://github.com/SVGKit/SVGKit.git
// Or via CocoaPods: pod 'SVGKit'

struct SVGKitView: UIViewRepresentable {
    let svgString: String
    let contentMode: UIView.ContentMode
    
    init(svg: String, contentMode: UIView.ContentMode = .scaleAspectFit) {
        self.svgString = svg
        self.contentMode = contentMode
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.contentMode = contentMode
        
        // Convert SVG string to data
        guard let svgData = svgString.data(using: .utf8) else {
            print("⚠️ SVGKitView: Failed to convert SVG string to data")
            addWebViewFallback(to: containerView)
            return containerView
        }
        
        // Use SVGKit to parse and render SVG natively
        // SVGKit provides SVGKImage which can render SVG natively
        // Check if SVGKit is available at compile time
        #if canImport(SVGKit)
        let svgImage = SVGKImage(data: svgData)
        
        // Prefer layer view for better rendering and performance
        if let svgImage = svgImage, let svgLayerView = svgImage.svgLayerView {
            svgLayerView.translatesAutoresizingMaskIntoConstraints = false
            svgLayerView.backgroundColor = .clear
            containerView.addSubview(svgLayerView)
            
            NSLayoutConstraint.activate([
                svgLayerView.topAnchor.constraint(equalTo: containerView.topAnchor),
                svgLayerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                svgLayerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                svgLayerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            // Store reference to SVG image for scaling
            objc_setAssociatedObject(containerView, &AssociatedKeys.svgImage, svgImage, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            // Scale will be handled in updateUIView when bounds are set
            return containerView
        } else if let svgImage = svgImage, let uiImage = svgImage.uiImage {
            // Fallback to UIImage if layer view not available
            let imageView = UIImageView(image: uiImage)
            imageView.contentMode = contentMode
            imageView.backgroundColor = .clear
            imageView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(imageView)
            
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
                imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            return containerView
        } else {
            print("⚠️ SVGKitView: SVGKImage created but no view available, using WKWebView fallback")
            addWebViewFallback(to: containerView)
            return containerView
        }
        #else
        // SVGKit not available - use WKWebView fallback
        print("ℹ️ SVGKitView: SVGKit not available, using WKWebView fallback")
        addWebViewFallback(to: containerView)
        return containerView
        #endif
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        #if canImport(SVGKit)
        // Update SVG scaling when view size changes
        if let svgImage = objc_getAssociatedObject(uiView, &AssociatedKeys.svgImage) as? SVGKImage,
           uiView.bounds.size.width > 0 && uiView.bounds.size.height > 0 {
            svgImage.scaleToFit(inside: uiView.bounds.size)
        }
        #endif
    }
    
    // MARK: - Associated Object Keys
    
    private struct AssociatedKeys {
        static var svgImage = "svgImage"
    }
    
    // MARK: - Helper Methods
    
    private func addWebViewFallback(to containerView: UIView) {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.isAccessibilityElement = false
        
        // Load SVG in HTML wrapper
        webView.loadHTMLString(
            """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
                <style>
                    * { margin: 0; padding: 0; box-sizing: border-box; }
                    html, body { width: 100%; height: 100%; overflow: hidden; background: transparent; }
                    svg { width: 100%; height: 100%; max-width: 100%; max-height: 100%; }
                </style>
            </head>
            <body>
                \(svgString)
            </body>
            </html>
            """,
            baseURL: nil
        )
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: containerView.topAnchor),
            webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
    }
}
