# Complete Rendering Flow - File by File Explanation

## Overview
This document explains exactly how content flows from JSON files to rendered views, step by step, file by file.

---

## 1. JSON File Structure
**File**: `Education/Resources/raw_json/sample2/sample2_page1.json`

### Structure:
```json
{
  "type": "doc",
  "content": [
    {
      "type": "svgNode",  // ← SVG graphic
      "attrs": {
        "svgContent": "<svg>...</svg>",
        "title": "Geometric Shape",
        "summary": [...],
        "long_desc": [...]
      }
    },
    {
      "type": "image",  // ← Regular image
      "attrs": {
        "src": "data:image/png;base64,...",
        "alt": ["The image shows..."],  // ← Array or string
        "long_desc": [...],
        "title": "Butterfly Illustration"
      }
    }
  ]
}
```

**Key Points:**
- `svgNode` = SVG graphics (lines, circles, text) → render on canvas
- `image` = Regular images (PNG/JPEG) → render as normal images
- `alt` can be a string OR an array (we take first element)

---

## 2. LessonStore.swift - Loading JSON
**File**: `Education/Core/Services/LessonStore.swift`

### Function: `loadNodes(forFilenames:)` (Line 157)

```swift
func loadNodes(forFilenames files: [String]) -> [Node] {
    var all: [Node] = []
    
    for f in files {
        // Skip problematic files
        if f == "sample2_page2" || f == "sample2_page2.json" {
            continue
        }
        
        // Load JSON file from bundle
        if let data = try? loadBundleJSON(named: f) {
            // Parse JSON into Node array
            let pageNodes = FlexibleLessonParser.parseNodes(from: data)
            all.append(contentsOf: pageNodes)
        }
    }
    
    return all  // Returns [Node] array
}
```

**What it does:**
1. Takes array of filenames (e.g., `["sample2_page1"]`)
2. Loads each JSON file from bundle
3. Calls `FlexibleLessonParser.parseNodes()` to convert JSON → `[Node]`
4. Returns combined array of all nodes

**Output**: `[Node]` array containing `.heading`, `.paragraph`, `.image`, `.svgNode` cases

---

## 3. LessonModels.swift - Parsing JSON to Nodes
**File**: `Education/Core/Models/LessonModels.swift`

### Function: `parseNodeDict(_:)` (Line 133)

**For SVG Nodes** (Line 170):
```swift
if rawType == "svgnode" || rawType == "svg" {
    let attrs = d["attrs"] as? [String: Any]
    let svg = attrs?["svgContent"] as? String ?? ""
    let title = attrs?["title"] as? String
    let long = attrs?["long_desc"] as? [String]
    let summary = attrs?["summary"] as? [String]
    
    return .svgNode(svg: svg, title: title, summaries: long ?? summary ?? short)
}
```

**For Image Nodes** (Line 150):
```swift
if rawType == "image" || rawType == "img" {
    let attrs = d["attrs"] as? [String: Any]
    let src = attrs?["src"] as? String ?? ""
    
    // Handle alt as String OR array
    let alt: String?
    if let altString = attrs?["alt"] as? String {
        alt = altString
    } else if let altArray = attrs?["alt"] as? [String], let first = altArray.first {
        alt = first  // ← Takes first element if array
    } else if let longDesc = attrs?["long_desc"] as? [String], let first = longDesc.first {
        alt = first  // ← Fallback to long_desc
    } else {
        alt = nil
    }
    
    return .image(src: src, alt: alt)
}
```

**What it does:**
1. Checks `type` field in JSON
2. Extracts `attrs` dictionary
3. For images: Handles `alt` as string or array (takes first)
4. Returns `Node` enum case (`.image` or `.svgNode`)

**Output**: `Node` enum cases ready for rendering

---

## 4. DocumentRendererView.swift - Main View
**File**: `Education/Features/Reader/DocumentRendererView.swift`

### Structure (Line 13):
```swift
struct DocumentRendererView: View {
    let title: String
    let nodes: [Node]  // ← Array of parsed nodes
    
    var body: some View {
        ScrollView {
            VStack {
                ForEach(filteredNodes) { node in
                    DocumentNodeView(node: node)  // ← Routes to correct view
                }
            }
        }
    }
}
```

**What it does:**
1. Receives `[Node]` array from `LessonStore`
2. Filters out problematic nodes (e.g., third SVG)
3. Loops through nodes and creates `DocumentNodeView` for each

---

## 5. DocumentNodeView.swift - Node Router
**File**: `Education/Features/Reader/DocumentRendererView.swift` (Line 107)

### Function: `body` (Line 114)
```swift
private struct DocumentNodeView: View {
    let node: Node
    
    var body: some View {
        switch node {
        case .heading(let level, let text):
            Text(text)  // ← Render heading
            
        case .paragraph(let items):
            DocumentParagraphView(items: items)  // ← Render paragraph
            
        case .image(let src, let alt):
            DocumentImageView(dataURI: src, alt: alt)  // ← ROUTE TO IMAGE VIEW
                .frame(maxWidth: .infinity, alignment: .leading)
            
        case .svgNode(let svg, let t, let d):
            DocumentSVGView(svg: svg, title: t, summaries: d)  // ← ROUTE TO SVG VIEW
            
        case .unknown:
            EmptyView()
        }
    }
}
```

**What it does:**
- **Router**: Switches on `Node` type and routes to appropriate view
- **`.image`** → `DocumentImageView` (renders normal image)
- **`.svgNode`** → `DocumentSVGView` (renders on canvas)

---

## 6. DocumentImageView.swift - Image Rendering
**File**: `Education/Features/Reader/DocumentRendererView.swift` (Line 234)

### Structure:
```swift
private struct DocumentImageView: View {
    let dataURI: String  // ← "data:image/png;base64,..."
    let alt: String?     // ← VoiceOver description
    
    @State private var decodedImage: UIImage? = nil
    @State private var isLoading: Bool = true
    
    // Static cache to prevent re-decoding
    private static var imageCache: [String: UIImage] = [:]
    private static let cacheQueue = DispatchQueue(...)
}
```

### Function: `body` (Line 252)
```swift
var body: some View {
    Group {
        if let img = decodedImage {
            // ✅ RENDER IMAGE
            Image(uiImage: img)
                .resizable()
                .scaledToFit()  // ← Maintains aspect ratio
                .frame(maxWidth: .infinity)  // ← Fills container width
                .frame(maxHeight: maxImageHeight)  // ← Caps height (350/500pt)
                .accessibilityLabel(alt ?? "Image")  // ← VoiceOver description
        } else if isLoading {
            // Placeholder while loading
            Rectangle().fill(Color(hex: "#DEECF8"))
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .onAppear {
        loadImage()  // ← Decode image when view appears
    }
}
```

### Function: `loadImage()` (Line 287)
```swift
private func loadImage() {
    // 1. Check cache first (fast)
    if let cached = imageCache[dataURI] {
        decodedImage = cached
        return
    }
    
    // 2. Decode on background thread
    DispatchQueue.global(qos: .userInitiated).async {
        // Extract base64 from data URI
        let base64 = String(dataURI[range.upperBound...])
        let data = Data(base64Encoded: base64)
        let img = UIImage(data: data)
        
        // 3. Cache it
        imageCache[dataURI] = img
        
        // 4. Update UI on main thread
        DispatchQueue.main.async {
            decodedImage = img
            isLoading = false
        }
    }
}
```

**What it does:**
1. **Receives**: `dataURI` (base64 string) and `alt` (VoiceOver text)
2. **Checks cache**: If image already decoded, use it
3. **Decodes**: Base64 → `UIImage` on background thread
4. **Caches**: Stores decoded image to prevent re-decoding
5. **Renders**: Simple `.scaledToFit()` with width/height constraints
6. **VoiceOver**: Uses `alt` text from JSON

**Key Points:**
- ✅ **Simple rendering**: No cropping, no complex calculations
- ✅ **Cached**: Prevents re-decoding on every render
- ✅ **Background thread**: Doesn't block UI
- ✅ **VoiceOver**: Uses `alt` from JSON

---

## 7. DocumentSVGView.swift - SVG Rendering
**File**: `Education/Features/Reader/DocumentRendererView.swift` (Line 333)

### Structure:
```swift
private struct DocumentSVGView: View {
    let svg: String  // ← Raw SVG XML string
    let title: String?
    let summaries: [String]?
    
    @State private var parsedGraphic: ParsedGraphic? = nil
    @State private var isLoading: Bool = true
}
```

### Function: `hasTactileElements` (Line 349)
```swift
private var hasTactileElements: Bool {
    svg.contains("<line") || 
    svg.contains("<circle") || 
    svg.contains("<polygon") || 
    svg.contains("<path")
}
```

**What it does:**
- Checks if SVG has tactile elements (lines, circles, etc.)
- If YES → render on `TactileCanvasView` (canvas)
- If NO → render with `SVGWebView` (web view)

### Function: `body` (Line 393)
```swift
var body: some View {
    VStack {
        if let title = title {
            Text(title)  // ← Title text
        }
        
        if hasTactileElements {
            // ✅ RENDER ON CANVAS
            let scene = SVGToTactileParser.parse(svgContent: svg, viewSize: .zero)
            let aspectSize = CGSize(
                width: max(1, scene.viewBox.width),
                height: max(1, scene.viewBox.height)
            )
            
            GeometryReader { geometry in
                TactileCanvasView(scene: scene, title: title, summaries: summaries)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .aspectRatio(aspectSize.width / aspectSize.height, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: 250)
        } else {
            // Fallback: render with web view
            SVGWebView(svg: svg)
        }
    }
    .onAppear {
        if parsedGraphic == nil && isLoading {
            loadParsedGraphic()  // ← Async parsing (optional, for caching)
        }
    }
}
```

**What it does:**
1. **Checks**: Does SVG have tactile elements?
2. **If YES**: 
   - Parses SVG with `SVGToTactileParser.parse()`
   - Creates `TactileScene` object
   - Renders on `TactileCanvasView` (canvas-based)
3. **If NO**: Renders with `SVGWebView` (web view)

**Key Points:**
- ✅ **SVG nodes render on canvas** via `TactileCanvasView`
- ✅ **Parses SVG** to extract lines, circles, text labels
- ✅ **Maintains aspect ratio** from SVG viewBox

---

## 8. SVGToTactileParser.swift - SVG Parsing
**File**: `Education/Core/Services/SVGToTactileParser.swift`

### Function: `parse(svgContent:viewSize:)`
```swift
static func parse(svgContent: String, viewSize: CGSize) -> TactileScene {
    // 1. Extract viewBox from SVG
    let viewBox = extractViewBox(from: svgContent)
    
    // 2. Parse lines from <line> tags
    let lines = extractLines(from: svgContent)
    
    // 3. Parse circles from <circle> tags
    let circles = extractCircles(from: svgContent)
    
    // 4. Parse text labels from <text> tags
    let rawTexts = extractTexts(from: svgContent)
    
    // 5. Combine nearby text labels (e.g., "35" + "in" → "35 in")
    let combinedLabels = combineNearbyTextLabels(labels: rawTexts)
    
    // 6. Associate labels with lines (position adjustment)
    let adjustedLabels = associateLabelsWithLines(labels: combinedLabels, lines: lines)
    
    // 7. Create TactileScene
    return TactileScene(
        viewBox: viewBox,
        lines: lines,
        circles: circles,
        labels: adjustedLabels
    )
}
```

**What it does:**
1. Parses SVG XML to extract elements
2. Combines text labels (e.g., "35" + "in" → "35 in")
3. Adjusts label positions relative to lines
4. Returns `TactileScene` object

**Output**: `TactileScene` with lines, circles, labels ready for canvas rendering

---

## 9. TactileCanvasView.swift - Canvas Rendering
**File**: `Education/Features/Reader/TactileCanvasView.swift`

### Function: `body`
```swift
var body: some View {
    GeometryReader { geometry in
        Canvas { context, size in
            // 1. Transform coordinates from viewBox to canvas
            let transform = calculateTransform(viewBox: scene.viewBox, canvasSize: size)
            
            // 2. Draw lines
            for line in scene.lines {
                context.stroke(Path(...), with: .color(.black), lineWidth: 2)
            }
            
            // 3. Draw circles
            for circle in scene.circles {
                context.fill(Path(...), with: .color(.black))
            }
            
            // 4. Draw text labels
            for label in scene.labels {
                context.draw(Text(label.text), at: transformPoint(label.position))
            }
        }
    }
}
```

**What it does:**
1. Uses SwiftUI `Canvas` to draw
2. Transforms coordinates from SVG viewBox to screen coordinates
3. Draws lines, circles, and text labels
4. Handles touch interactions for haptic feedback

**Key Points:**
- ✅ **SVG renders on canvas** (not as image)
- ✅ **Interactive**: Touch tracking for haptics
- ✅ **Accessible**: Single VoiceOver element

---

## 10. WorksheetView.swift - Similar Flow
**File**: `Education/Features/WorksheetView.swift`

### Structure:
- **NodeBlockView** (Line 292): Similar to `DocumentNodeView` - routes nodes
- **ImageBlockView** (Line 453): Identical to `DocumentImageView`
- **SVGBlockView** (Line 566): Similar to `DocumentSVGView` but simpler (no async parsing)

**Key Difference:**
- `SVGBlockView` uses synchronous parsing (line 587):
  ```swift
  let scene = SVGToTactileParser.parse(svgContent: svg, viewSize: .zero)
  ```
- No async `loadParsedGraphic()` - parses directly

---

## Complete Flow Diagram

```
JSON File (sample2_page1.json)
  │
  ├─> LessonStore.loadNodes(forFilenames:)
  │   └─> Loads JSON from bundle
  │
  ├─> FlexibleLessonParser.parseNodes(from:)
  │   └─> parseNodeDict() for each node
  │       │
  │       ├─> type: "svgNode" → Node.svgNode(svg, title, summaries)
  │       └─> type: "image" → Node.image(src, alt)
  │
  ├─> DocumentRendererView
  │   └─> ForEach(filteredNodes)
  │       └─> DocumentNodeView(node)
  │           │
  │           ├─> case .image → DocumentImageView
  │           │   ├─> loadImage() [background thread]
  │           │   │   ├─> Check cache
  │           │   │   ├─> Decode base64 → UIImage
  │           │   │   └─> Cache result
  │           │   └─> Image(uiImage:)
  │           │       .scaledToFit()
  │           │       .frame(maxWidth: .infinity)
  │           │       .frame(maxHeight: 350/500)
  │           │       .accessibilityLabel(alt)  ← VoiceOver
  │           │
  │           └─> case .svgNode → DocumentSVGView
  │               ├─> hasTactileElements? (checks for <line>, <circle>, etc.)
  │               │
  │               ├─> YES → TactileCanvasView
  │               │   ├─> SVGToTactileParser.parse()
  │               │   │   ├─> Extract viewBox
  │               │   │   ├─> Parse lines, circles, text
  │               │   │   ├─> Combine text labels
  │               │   │   └─> Adjust positions
  │               │   │
  │               │   └─> TactileCanvasView(scene:)
  │               │       └─> Canvas { context, size in
  │               │           ├─> Draw lines
  │               │           ├─> Draw circles
  │               │           └─> Draw text labels
  │               │
  │               └─> NO → SVGWebView (fallback)
```

---

## Current Issues & Why Images Don't Fit

### Issue 1: Image Sizing
**Problem**: `.scaledToFit()` with `.frame(maxWidth: .infinity)` and `.frame(maxHeight: ...)` can cause sizing conflicts.

**Current Code** (Line 255-259):
```swift
Image(uiImage: img)
    .resizable()
    .scaledToFit()
    .frame(maxWidth: .infinity)  // ← Wants full width
    .frame(maxHeight: maxImageHeight)  // ← Caps height
```

**What happens:**
- SwiftUI tries to fit image within both constraints
- If aspect ratio doesn't match, image might not fill width
- Or height might exceed max, causing clipping

### Issue 2: Container Constraints
**Problem**: Parent container might not be providing proper width.

**Container Chain**:
```
ScrollView
  └─> VStack (padding: Spacing.screenPadding = 24pt)
      └─> VStack (padding: Spacing.large = 24pt)
          └─> DocumentNodeView
              └─> DocumentImageView
                  └─> Group
                      └─> Image
```

**Available width calculation:**
- Screen width: 402pt (iPhone)
- Minus ScrollView padding: 402 - (24 * 2) = 354pt
- Minus VStack padding: 354 - (24 * 2) = 306pt
- **But**: `Group` doesn't expand, so image might not get full width

---

## Solutions

### For Images:
1. **Remove Group wrapper** - Let image expand directly
2. **Use explicit aspect ratio** - Calculate from image dimensions
3. **Set explicit frame** - Based on container width

### For SVGs:
1. **Already correct** - Renders on `TactileCanvasView` ✅
2. **Canvas handles sizing** - Uses viewBox aspect ratio ✅

---

## File Summary

| File | Purpose | Key Function |
|------|---------|--------------|
| `sample2_page1.json` | Data source | Contains SVG and image nodes |
| `LessonStore.swift` | Data loader | `loadNodes()` - loads JSON files |
| `LessonModels.swift` | Parser | `parseNodeDict()` - JSON → Node enum |
| `DocumentRendererView.swift` | Main view | Routes nodes to appropriate views |
| `DocumentNodeView.swift` | Router | `switch node` - routes to image/SVG view |
| `DocumentImageView.swift` | Image renderer | Renders normal images with caching |
| `DocumentSVGView.swift` | SVG router | Routes to canvas or web view |
| `SVGToTactileParser.swift` | SVG parser | Parses SVG XML → TactileScene |
| `TactileCanvasView.swift` | Canvas renderer | Draws SVG on SwiftUI Canvas |
| `WorksheetView.swift` | Worksheet view | Similar flow for worksheets |

---

## Next Steps to Fix Image Fitting

1. **Remove Group wrapper** from `DocumentImageView` and `ImageBlockView`
2. **Calculate explicit dimensions** based on container width
3. **Use aspect ratio** from image dimensions
4. **Set explicit frame** on image

Let me know if you want me to implement these fixes!
