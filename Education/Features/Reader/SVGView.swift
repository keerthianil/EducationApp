//
//  SVGView.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//
//  Renders SVG graphics using WKWebView from graphicData JSON.
//  The parent SwiftUI view provides the single accessibility label for the entire graphic.
//

import Foundation
import SwiftUI
import WebKit


struct SVGView: UIViewRepresentable {
    let svg: String
    let graphicData: [String: Any]?
    
    init(svg: String, graphicData: [String: Any]? = nil) {
        self.svg = svg
        self.graphicData = graphicData
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        // Disable interaction so taps go to the surrounding SwiftUI Button
        webView.isUserInteractionEnabled = false
        webView.scrollView.isUserInteractionEnabled = false

        // CRITICAL: COMPLETELY disable accessibility on the WebView
        // This prevents VoiceOver from jumping to internal SVG elements
        // The parent SwiftUI view handles all accessibility
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        webView.accessibilityTraits = []

        webView.scrollView.isAccessibilityElement = false
        webView.scrollView.accessibilityElementsHidden = true

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // FORCE CLEAR: Clear any cached content first
        webView.stopLoading()
        webView.evaluateJavaScript("document.body.innerHTML = '';") { _, _ in }
        
        // ONLY use graphicData - no fallback to SVG parsing
        guard let graphicData = graphicData else {
            #if DEBUG
            print("❌ SVGView: graphicData is nil")
            #endif
            let errorHTML = """
            <!DOCTYPE html>
            <html>
            <head>
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <style>
                body { 
                  margin: 0; padding: 20px; display: flex; 
                  align-items: center; justify-content: center; height: 100vh;
                  font-family: -apple-system, sans-serif; color: #f00;
                  text-align: center; background: #fff;
                }
              </style>
            </head>
            <body>
              <div style="border: 2px solid #f00; padding: 20px; border-radius: 8px;">
                <strong>Graphic data not available</strong>
              </div>
            </body>
            </html>
            """
            webView.loadHTMLString(errorHTML, baseURL: nil)
            return
        }
        
        // Convert graphicData dictionary to JSON string
        guard let jsonData = try? JSONSerialization.data(withJSONObject: graphicData, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            #if DEBUG
            print("❌ SVGView: Failed to serialize graphicData")
            if let lines = graphicData["lines"] as? [[String: Any]] {
                print("  graphicData has \(lines.count) lines")
            } else {
                print("  graphicData missing lines array")
            }
            #endif
            let errorHTML = """
            <!DOCTYPE html>
            <html>
            <head>
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <style>
                body { 
                  margin: 0; padding: 20px; display: flex; 
                  align-items: center; justify-content: center; height: 100vh;
                  font-family: -apple-system, sans-serif; color: #f00;
                  text-align: center; background: #fff;
                }
              </style>
            </head>
            <body>
              <div style="border: 2px solid #f00; padding: 20px; border-radius: 8px;">
                <strong>Invalid graphic data</strong><br/>
                Failed to serialize
              </div>
            </body>
            </html>
            """
            webView.loadHTMLString(errorHTML, baseURL: nil)
            return
        }
        
        let svgJSON = jsonString
        #if DEBUG
        print("🔵 SVGView: Using graphicData JSON ONLY, length: \(svgJSON.count)")
        if let jsonData = svgJSON.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            if let lines = jsonObject["lines"] as? [[String: Any]] {
                print("🔵 SVGView: Found \(lines.count) lines")
            }
            if let labels = jsonObject["labels"] as? [[String: Any]] {
                print("🔵 SVGView: Found \(labels.count) labels in graphicData")
                for (index, label) in labels.enumerated() {
                    if let text = label["text"] as? String {
                        print("  Label \(index): '\(text)'")
                    }
                }
            } else {
                print("⚠️ SVGView: No labels array found")
            }
        }
        #endif
        
        // Escape JSON string for safe embedding in JavaScript
        let escapedJSON = svgJSON
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
        
        // Add cache-busting timestamp
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"/>
          <style>
            * { 
              -webkit-user-select: none; 
              user-select: none; 
              -webkit-touch-callout: none; 
              margin: 0;
              padding: 0;
            }
            html, body { 
              margin: 0; 
              padding: 0; 
              width: 100%; 
              height: 100%; 
              background: transparent; 
              overflow: hidden; 
              display: flex;
              align-items: center;
              justify-content: center;
            }
            #svg-container-\(timestamp) {
              width: 100%;
              height: 100%;
              display: flex;
              align-items: center;
              justify-content: center;
              overflow: visible;
              min-height: 200px;
            }
            svg { 
              max-width: 100%; 
              max-height: 100%;
              width: 100%;
              height: auto; 
              display: block;
            }
            svg * { 
              pointer-events: none; 
            }
          </style>
        </head>
        <body aria-hidden="true" role="presentation" tabindex="-1" inert>
          <div id="svg-container-\(timestamp)"></div>
          <script>
            (function() {
              'use strict';
              
              function forceRenderFromJSON() {
                try {
                  const container = document.getElementById('svg-container-\(timestamp)');
                  if (!container) {
                    console.error('SVG container not found');
                    return;
                  }
                  
                  container.innerHTML = '';
                  
                  const jsonString = '\(escapedJSON)';
                  console.log('🔵 Parsing JSON, length:', jsonString.length);
                  const svgData = JSON.parse(jsonString);
                  console.log('🔵 JSON parsed successfully');
                  
                  // Determine viewBox - handle both formats
                  let viewBoxStr = '0 0 448 380';
                  if (svgData.viewBox) {
                    if (typeof svgData.viewBox === 'string') {
                      viewBoxStr = svgData.viewBox;
                    } else if (svgData.viewBox.x !== undefined) {
                      viewBoxStr = svgData.viewBox.x + ' ' + svgData.viewBox.y + ' ' + 
                                   svgData.viewBox.width + ' ' + svgData.viewBox.height;
                    }
                  }
                  
                  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
                  svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
                  svg.setAttribute('viewBox', viewBoxStr);
                  svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
                  const viewBoxParts = viewBoxStr.split(' ');
                  const viewBoxWidth = parseFloat(viewBoxParts[2]) || 448;
                  const viewBoxHeight = parseFloat(viewBoxParts[3]) || 380;
                  const aspectRatio = viewBoxWidth / viewBoxHeight;
                  
                  svg.setAttribute('style', 'max-width:100%;max-height:100%;width:100%;height:auto;display:block;visibility:visible;');
                  svg.setAttribute('aria-hidden', 'true');
                  
                  container.style.visibility = 'visible';
                  container.style.display = 'flex';
                  container.style.minHeight = '200px';
                  
                  if (!svgData.lines || !Array.isArray(svgData.lines)) {
                    console.error('❌ Invalid graphicData: missing lines array');
                    console.error('❌ svgData keys:', Object.keys(svgData));
                    container.innerHTML = '<div style="padding:20px;text-align:center;color:#f00;background:#fff;border:2px solid #f00;border-radius:8px;"><strong>Invalid graphic data format</strong><br/>Missing lines array</div>';
                    return;
                  }
                  
                  console.log('🔵 Rendering from graphicData format ONLY');
                  console.log('🔵 Lines count:', svgData.lines.length);
                  console.log('🔵 ViewBox:', viewBoxStr);
                  
                  // Render lines
                  const linesGroup = document.createElementNS('http://www.w3.org/2000/svg', 'g');
                  linesGroup.setAttribute('id', 'lines');
                  svgData.lines.forEach(function(line) {
                    const el = document.createElementNS('http://www.w3.org/2000/svg', 'line');
                    if (line.id) el.setAttribute('id', line.id);
                    el.setAttribute('stroke', 'rgb(0%,0%,0%)');
                    el.setAttribute('stroke-width', String(line.strokeWidth || 1));
                    el.setAttribute('x1', String(line.x1 || 0));
                    el.setAttribute('x2', String(line.x2 || 0));
                    el.setAttribute('y1', String(line.y1 || 0));
                    el.setAttribute('y2', String(line.y2 || 0));
                    linesGroup.appendChild(el);
                  });
                  svg.appendChild(linesGroup);
                  console.log('🔵 Rendered', svgData.lines.length, 'lines');
                  
                  // Render vertices (points)
                  if (svgData.vertices && Array.isArray(svgData.vertices)) {
                    const pointsGroup = document.createElementNS('http://www.w3.org/2000/svg', 'g');
                    pointsGroup.setAttribute('id', 'points');
                    svgData.vertices.forEach(function(vertex) {
                      const el = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
                      if (vertex.id) el.setAttribute('id', vertex.id);
                      el.setAttribute('cx', String(vertex.x || 0));
                      el.setAttribute('cy', String(vertex.y || 0));
                      el.setAttribute('r', '2');
                      el.setAttribute('fill', 'rgb(0,0,0)');
                      el.setAttribute('stroke', 'rgb(0,0,0)');
                      pointsGroup.appendChild(el);
                    });
                    svg.appendChild(pointsGroup);
                    console.log('🔵 Rendered', svgData.vertices.length, 'vertices');
                  }
                  
                  // Render labels
                  if (svgData.labels && Array.isArray(svgData.labels)) {
                    const textsGroup = document.createElementNS('http://www.w3.org/2000/svg', 'g');
                    textsGroup.setAttribute('id', 'texts');
                    console.log('🔵 Rendering', svgData.labels.length, 'labels');
                    svgData.labels.forEach(function(label, index) {
                      if (!label.text || label.text.trim() === '') {
                        console.log('  Skipping empty label at index', index);
                        return;
                      }
                      console.log('  Label', index, ':', label.text);
                      const el = document.createElementNS('http://www.w3.org/2000/svg', 'text');
                      if (label.id) el.setAttribute('id', label.id);
                      el.setAttribute('x', String(label.x || 0));
                      el.setAttribute('y', String(label.y || 0));
                      el.setAttribute('fill', '#000000');
                      el.setAttribute('font-size', String(label.fontSize || 15) + 'px');
                      el.textContent = label.text;
                      textsGroup.appendChild(el);
                    });
                    svg.appendChild(textsGroup);
                    console.log('🔵 Rendered labels');
                  } else {
                    console.warn('⚠️ No labels array found');
                  }
                  
                  container.appendChild(svg);
                  console.log('🔵 SVG rendered successfully');
                  console.log('🔵 SVG element:', svg);
                  console.log('🔵 Container children:', container.children.length);
                  
                  // Force a repaint
                  setTimeout(function() {
                    const rect = svg.getBoundingClientRect();
                    console.log('🔵 SVG dimensions:', rect.width, 'x', rect.height);
                    if (rect.width === 0 || rect.height === 0) {
                      console.error('❌ SVG has zero dimensions!');
                    }
                  }, 100);
                  
                } catch (error) {
                  console.error('❌ SVG rendering error:', error);
                  console.error('❌ Error stack:', error.stack);
                  console.error('❌ JSON string length:', jsonString ? jsonString.length : 0);
                }
              }
              
              if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', forceRenderFromJSON);
              } else {
                forceRenderFromJSON();
              }
            })();
          </script>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)

        // CRITICAL: Ensure WebView accessibility is COMPLETELY disabled after load
        webView.isAccessibilityElement = false
        webView.accessibilityElementsHidden = true
        webView.accessibilityTraits = []

        webView.scrollView.isAccessibilityElement = false
        webView.scrollView.accessibilityElementsHidden = true
    }
}
