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
    let graphicData: [String: Any]?
    
    init(svg: String, graphicData: [String: Any]? = nil) {
        self.svg = svg
        self.graphicData = graphicData
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Disable caching to ensure fresh content
        if #available(iOS 9.0, *) {
            config.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        }
        
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
        // FORCE CLEAR: Clear any cached content first
        webView.stopLoading()
        webView.evaluateJavaScript("document.body.innerHTML = '';") { _, _ in }
        
        // ONLY use graphicData - no fallback to SVG parsing
        guard let graphicData = graphicData else {
            #if DEBUG
            print("❌ SVGView: graphicData is nil")
            #endif
            // No graphicData available - show error message
            let errorHTML = """
            <!DOCTYPE html>
            <html>
            <head>
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <style>
                body { 
                  margin: 0; 
                  padding: 20px; 
                  display: flex; 
                  align-items: center; 
                  justify-content: center; 
                  height: 100vh;
                  font-family: -apple-system, sans-serif;
                  color: #f00;
                  text-align: center;
                  background: #fff;
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
            // Failed to serialize graphicData - show error
            let errorHTML = """
            <!DOCTYPE html>
            <html>
            <head>
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <style>
                body { 
                  margin: 0; 
                  padding: 20px; 
                  display: flex; 
                  align-items: center; 
                  justify-content: center; 
                  height: 100vh;
                  font-family: -apple-system, sans-serif;
                  color: #f00;
                  text-align: center;
                  background: #fff;
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
        
        // Step 3: Escape JSON string for safe embedding in JavaScript
        let escapedJSON = svgJSON
            .replacingOccurrences(of: "\\", with: "\\\\")  // Escape backslashes
            .replacingOccurrences(of: "'", with: "\\'")      // Escape single quotes
            .replacingOccurrences(of: "\"", with: "\\\"")   // Escape double quotes
            .replacingOccurrences(of: "\n", with: "\\n")     // Escape newlines
            .replacingOccurrences(of: "\r", with: "\\r")    // Escape carriage returns
            .replacingOccurrences(of: "\t", with: "\\t")    // Escape tabs
        
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
                  
                  // FORCE CLEAR: Clear container completely
                  container.innerHTML = '';
                  
                  // Parse JSON
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
                      // graphicData format: {x, y, width, height}
                      viewBoxStr = svgData.viewBox.x + ' ' + svgData.viewBox.y + ' ' + 
                                   svgData.viewBox.width + ' ' + svgData.viewBox.height;
                    }
                  }
                  
                  // Create SVG element
                  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
                  svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
                  svg.setAttribute('viewBox', viewBoxStr);
                  svg.setAttribute('preserveAspectRatio', 'xMidYMid meet');
                  // Calculate aspect ratio from viewBox to maintain proper scaling
                  const viewBoxParts = viewBoxStr.split(' ');
                  const viewBoxWidth = parseFloat(viewBoxParts[2]) || 448;
                  const viewBoxHeight = parseFloat(viewBoxParts[3]) || 380;
                  const aspectRatio = viewBoxWidth / viewBoxHeight;
                  
                  // Set SVG to fit container while maintaining aspect ratio
                  svg.setAttribute('style', 'max-width:100%;max-height:100%;width:100%;height:auto;display:block;visibility:visible;');
                  svg.setAttribute('aria-hidden', 'true');
                  
                  // Ensure container is visible and has proper dimensions
                  container.style.visibility = 'visible';
                  container.style.display = 'flex';
                  container.style.minHeight = '200px';
                  
                  // ONLY render from graphicData format - no fallback
                  if (!svgData.lines || !Array.isArray(svgData.lines)) {
                    console.error('❌ Invalid graphicData: missing lines array');
                    console.error('❌ svgData keys:', Object.keys(svgData));
                    container.innerHTML = '<div style="padding:20px;text-align:center;color:#f00;background:#fff;border:2px solid #f00;border-radius:8px;"><strong>Invalid graphic data format</strong><br/>Missing lines array</div>';
                    return;
                  }
                  
                  // graphicData format
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
                  
                  // Append to container
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
              
              // Force render immediately
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

    /// Parse SVG string into JSON structure for controlled rendering
    private func parseSVGToJSON(svg: String) -> String {
        var viewBox = "0 0 448 380"
        var groups: [String: [String: Any]] = [:]
        
        // Extract viewBox from SVG root
        if let viewBoxRegex = try? NSRegularExpression(pattern: #"viewBox\s*=\s*"([^"]+)""#, options: []) {
            let ns = svg as NSString
            if let match = viewBoxRegex.firstMatch(in: svg, range: NSRange(location: 0, length: ns.length)) {
                viewBox = ns.substring(with: match.range(at: 1))
            }
        }
        
        // Parse lines
        if let linesRegex = try? NSRegularExpression(pattern: #"<line\s+([^>]+)>"#, options: []) {
            var lineElements: [[String: String]] = []
            let ns = svg as NSString
            let matches = linesRegex.matches(in: svg, range: NSRange(location: 0, length: ns.length))
            
            for match in matches {
                let attrsString = ns.substring(with: match.range(at: 1))
                var line: [String: String] = [:]
                
                // Extract attributes
                extractAttributes(from: attrsString, into: &line)
                if !line.isEmpty {
                    lineElements.append(line)
                }
            }
            
            if !lineElements.isEmpty {
                groups["lines"] = ["elements": lineElements]
            }
        }
        
        // Parse points (circles)
        if let circlesRegex = try? NSRegularExpression(pattern: #"<circle\s+([^>]+)>"#, options: []) {
            var pointElements: [[String: String]] = []
            let ns = svg as NSString
            let matches = circlesRegex.matches(in: svg, range: NSRange(location: 0, length: ns.length))
            
            for match in matches {
                let attrsString = ns.substring(with: match.range(at: 1))
                var point: [String: String] = [:]
                
                extractAttributes(from: attrsString, into: &point)
                if !point.isEmpty {
                    pointElements.append(point)
                }
            }
            
            if !pointElements.isEmpty {
                groups["points"] = ["elements": pointElements]
            }
        }
        
        // Parse texts - handle both <text> and <text > with attributes
        // Use non-greedy matching to handle nested structures
        if let textsRegex = try? NSRegularExpression(pattern: #"<text\b([^>]*)>([\s\S]*?)</text>"#, options: [.dotMatchesLineSeparators]) {
            var textElements: [[String: String]] = []
            let ns = svg as NSString
            let matches = textsRegex.matches(in: svg, range: NSRange(location: 0, length: ns.length))
            
            for match in matches {
                let attrsString = ns.substring(with: match.range(at: 1))
                let contentRange = match.range(at: 2)
                let content = ns.substring(with: contentRange)
                
                var text: [String: String] = [:]
                if !attrsString.trimmingCharacters(in: .whitespaces).isEmpty {
                    extractAttributes(from: attrsString, into: &text)
                }
                
                // Extract visible text (strip any nested tags like <tspan>)
                let visibleText = extractVisibleText(from: content)
                
                // Only add if there's actual text content or attributes
                if !visibleText.isEmpty || !text.isEmpty {
                    text["text"] = visibleText
                    textElements.append(text)
                }
            }
            
            if !textElements.isEmpty {
                groups["texts"] = ["elements": textElements]
            }
        }
        
        // Build JSON structure
        var jsonDict: [String: Any] = ["viewBox": viewBox]
        if !groups.isEmpty {
            jsonDict["groups"] = groups
        }
        
        // Convert to JSON string
        guard let jsonData = try? JSONSerialization.data(withJSONObject: jsonDict, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
    
    /// Extract attributes from an attribute string (e.g., "id='line_1' x1='100' y1='200'")
    /// Handles both double-quoted and single-quoted attributes
    private func extractAttributes(from attrsString: String, into dict: inout [String: String]) {
        // Try double quotes first
        let doubleQuotePattern = #"(\w+(?:-\w+)*)\s*=\s*"([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: doubleQuotePattern, options: []) {
            let ns = attrsString as NSString
            let matches = regex.matches(in: attrsString, range: NSRange(location: 0, length: ns.length))
            
            for match in matches {
                let key = ns.substring(with: match.range(at: 1))
                let value = ns.substring(with: match.range(at: 2))
                dict[key] = value
            }
        }
        
        // Also try single quotes (fallback)
        let singleQuotePattern = #"(\w+(?:-\w+)*)\s*=\s*'([^']+)'"#
        if let regex = try? NSRegularExpression(pattern: singleQuotePattern, options: []) {
            let ns = attrsString as NSString
            let matches = regex.matches(in: attrsString, range: NSRange(location: 0, length: ns.length))
            
            for match in matches {
                let key = ns.substring(with: match.range(at: 1))
                let value = ns.substring(with: match.range(at: 2))
                // Only add if not already set (double quotes take precedence)
                if dict[key] == nil {
                    dict[key] = value
                }
            }
        }
    }
    
    /// Extract visible text from content, stripping nested tags
    private func extractVisibleText(from content: String) -> String {
        // Remove all tags
        let tagPattern = #"<[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: tagPattern, options: []) {
            let ns = content as NSString
            let result = regex.stringByReplacingMatches(
                in: content,
                range: NSRange(location: 0, length: ns.length),
                withTemplate: ""
            )
            return result.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Sanitize SVG to remove any accessibility attributes that might cause jumping
    /// + Fix broken labels like "28 Yd" followed by a separate "0" text node.
    private func sanitizeSVG(_ svg: String) -> String {
        var result = svg

        // -------------------------------
        // 1) Remove aria attributes
        // -------------------------------
        let ariaPattern = #"\s*aria-[a-z]+="[^"]*""#
        if let regex = try? NSRegularExpression(pattern: ariaPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result,
                                                    range: NSRange(result.startIndex..., in: result),
                                                    withTemplate: "")
        }

        // -------------------------------
        // 2) Remove role attributes
        // -------------------------------
        let rolePattern = #"\s*role="[^"]*""#
        if let regex = try? NSRegularExpression(pattern: rolePattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result,
                                                    range: NSRange(result.startIndex..., in: result),
                                                    withTemplate: "")
        }

        // -------------------------------
        // 3) Remove tabindex attributes
        // -------------------------------
        let tabPattern = #"\s*tabindex="[^"]*""#
        if let regex = try? NSRegularExpression(pattern: tabPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(in: result,
                                                    range: NSRange(result.startIndex..., in: result),
                                                    withTemplate: "")
        }

        // -------------------------------
        // ✅ 4) Fix label artifacts
        //    - Robustly removes standalone "0" labels even if wrapped in <tspan>
        // -------------------------------
        result = fixLabelArtifacts(in: result)

        // -------------------------------
        // 5) Add aria-hidden to the SVG root if not present
        // -------------------------------
        if !result.lowercased().contains("aria-hidden") {
            result = result.replacingOccurrences(of: "<svg",
                                                with: "<svg aria-hidden=\"true\"",
                                                options: .caseInsensitive)
        }

        return result
    }

    /// Fixes UNAR-style SVG label issues:
    /// - "35" + "0" → "35 in."
    /// - "50n" → "50 in."
    /// - Remove standalone "IN" and "0" nodes
    private func fixLabelArtifacts(in svg: String) -> String {
        var result = svg
        
        // Detect unit from metadata
        let lower = result.lowercased()
        var unitSuffix = " in."
        if lower.contains("ft") || lower.contains("feet") {
            unitSuffix = " ft."
        } else if lower.contains("yd") || lower.contains("yards") {
            unitSuffix = " yd."
        }

        // 1) Fix malformed labels like "50n" → "50 in."
        if let malformedRegex = try? NSRegularExpression(
            pattern: #"<text([^>]*)>\s*(\d+)\s*n\s*</text>"#,
            options: [.caseInsensitive]
        ) {
            result = malformedRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<text$1>$2\(unitSuffix)</text>"
            )
        }

        // 2) Remove standalone unit-only nodes like <text>IN</text>, <text>FT</text>, <text>YD</text>
        if let unitOnlyRegex = try? NSRegularExpression(
            pattern: #"<text\b[^>]*>\s*(IN|FT|YD)\s*</text>"#,
            options: [.caseInsensitive]
        ) {
            result = unitOnlyRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // 3) Remove "0" text nodes that follow numbers or ")"
        result = removeZeroTextNodesThatFollowCloseParen(in: result)
        
        // 4) Append units to numeric-only labels (after removing problematic "0" nodes)
        // Find all text nodes and append units to numeric-only ones
        if let numOnlyRegex = try? NSRegularExpression(
            pattern: #"<text([^>]*)>\s*(\d+)\s*</text>"#,
            options: []
        ) {
            result = numOnlyRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "<text$1>$2\(unitSuffix)</text>"
            )
        }

        // 5) Normalize "Yd"/"yd" to "yd."
        if let ydRegex = try? NSRegularExpression(
            pattern: #">(\d+)\s*Yd\.?<"#,
            options: []
        ) {
            result = ydRegex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ">$1 yd.<"
            )
        }
        if let ydRegex2 = try? NSRegularExpression(
            pattern: #">(\d+)\s*yd\.?<"#,
            options: []
        ) {
            result = ydRegex2.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ">$1 yd.<"
            )
        }

        return result
    }

    /// Removes "0" text nodes if they follow numbers or ")".
    /// This safely handles cases like "35" + "0", "28 Yd)" + "0" without removing valid "0" labels.
    private func removeZeroTextNodesThatFollowCloseParen(in svg: String) -> String {
        let ns = svg as NSString
        guard let textBlockRegex = try? NSRegularExpression(
            pattern: #"<text\b[^>]*>[\s\S]*?<\/text>"#,
            options: [.caseInsensitive]
        ) else { return svg }

        // Find all <text>...</text> blocks in order
        let matches = textBlockRegex.matches(in: svg, range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty { return svg }

        // Regex to strip tags inside a text node (<tspan>, etc.)
        let tagStripper = try? NSRegularExpression(pattern: #"<[^>]+>"#, options: [])
        
        // Extract visible text from each text node
        var textNodes: [(range: NSRange, visibleText: String, fullBlock: String)] = []
        
        for m in matches {
            let range = m.range
            let block = ns.substring(with: range)
            
            // Extract visible text (strip tags and trim)
            let visible: String
            if let tagStripper {
                let bns = block as NSString
                let stripped = tagStripper.stringByReplacingMatches(in: block, range: NSRange(location: 0, length: bns.length), withTemplate: "")
                visible = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                visible = block.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            textNodes.append((range: range, visibleText: visible, fullBlock: block))
        }
        
        // Identify which "0" nodes to remove (those that follow numbers or ")")
        var indicesToRemove = Set<Int>()
        for i in 0..<textNodes.count {
            let current = textNodes[i]
            let visible = current.visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if current is "0"
            if visible == "0" {
                // Remove if it's at the start, or follows a number or ")"
                if i == 0 {
                    indicesToRemove.insert(i)
                } else {
                    let previous = textNodes[i - 1]
                    let prevVisible = previous.visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Remove if previous ends with ")" or is a pure number
                    if prevVisible.hasSuffix(")") {
                        indicesToRemove.insert(i)
                    } else if prevVisible.range(of: #"^\d+$"#, options: .regularExpression) != nil {
                        indicesToRemove.insert(i)
                    }
                }
            }
        }
        
        // Rebuild the string, skipping the nodes we want to remove
        var output = ""
        var lastIndex = 0
        
        for (index, node) in textNodes.enumerated() {
            // Append everything before this match
            let beforeRange = NSRange(location: lastIndex, length: node.range.location - lastIndex)
            if beforeRange.length > 0 {
                output += ns.substring(with: beforeRange)
            }
            
            // Only append if we're not removing this node
            if !indicesToRemove.contains(index) {
                output += node.fullBlock
            }
            
            lastIndex = node.range.location + node.range.length
        }
        
        // Append remainder
        if lastIndex < ns.length {
            output += ns.substring(from: lastIndex)
        }
        
        return output
    }

    /// Removes any <text ...> ... </text> blocks whose *visible* (tag-stripped) text equals `target`.
    /// This is much more reliable than trying to match every SVG formatting variation with one regex.
    private func removeTextNodes(whoseVisibleTextIsExactly target: String, in svg: String) -> String {
        let ns = svg as NSString
        guard let textBlockRegex = try? NSRegularExpression(
            pattern: #"<text\b[^>]*>[\s\S]*?<\/text>"#,
            options: [.caseInsensitive]
        ) else { return svg }

        // Find all <text>...</text> blocks first
        let matches = textBlockRegex.matches(in: svg, range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty { return svg }

        // We'll rebuild the string while skipping the ones we want to remove
        var output = ""
        var lastIndex = 0

        // Regex to strip tags inside a text node (<tspan>, etc.)
        let tagStripper = try? NSRegularExpression(pattern: #"<[^>]+>"#, options: [])

        for m in matches {
            let range = m.range

            // Append everything before this match
            let beforeRange = NSRange(location: lastIndex, length: range.location - lastIndex)
            if beforeRange.length > 0 {
                output += ns.substring(with: beforeRange)
            }

            let block = ns.substring(with: range)
            let visible: String
            if let tagStripper {
                let bns = block as NSString
                let stripped = tagStripper.stringByReplacingMatches(in: block, range: NSRange(location: 0, length: bns.length), withTemplate: "")
                visible = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                visible = block.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            // If the visible text is exactly the target, skip this whole <text> block
            if visible == target {
                // do nothing (remove it)
            } else {
                output += block
            }

            lastIndex = range.location + range.length
        }

        // Append remainder
        if lastIndex < ns.length {
            output += ns.substring(from: lastIndex)
        }

        return output
    }
}

// MARK: - Alternative: UIKit-based SVG View for complete accessibility control

/// A UIKit wrapper that ensures the WebView is completely invisible to VoiceOver
class AccessibilityHiddenSVGView: UIView {
    private var webView: WKWebView?

    var svg: String = "" {
        didSet { loadSVG() }
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
