# Current Rendering Flow

## Overview
The app renders SVG graphics by parsing them into structured data, then rendering using SwiftUI Canvas.

## Complete Flow

### 1. **Data Loading** (`LessonStore.swift`)
```
JSON File (sample2_page1.json)
  └─> Contains: { "type": "svgNode", "attrs": { "svgContent": "<svg>...</svg>" } }
  └─> FlexibleLessonParser extracts SVG string
```

### 2. **SVG Parsing** (`DocumentRendererView.swift` → `SVGToTactileParser.swift`)

**First Run (Cache Miss):**
```
SVG String
  └─> SVGToTactileParser.parse(svgContent:)
      ├─> Extract viewBox
      ├─> Parse <line> elements → TactileLineSegment[]
      ├─> Parse <circle> elements → TactileVertex[]
      ├─> Parse <text> elements → TactileLabel[]
      ├─> Parse <path>, <rect>, <polygon>, <polyline> → TactileLineSegment[]
      ├─> Combine nearby labels (e.g., "35" + "IN" → "35 in")
      ├─> Associate labels with nearest lines
      ├─> Adjust label positions (above horizontal, left of vertical)
      └─> Return TactileScene
      
  └─> ParsedGraphic.from(TactileScene)
      └─> Convert to JSON-serializable ParsedGraphic
      
  └─> Cache as JSON (UserDefaults)
      └─> Key: "graphic_{title}_{svgHash}"
```

**Subsequent Runs (Cache Hit):**
```
Cache Key
  └─> GraphicCacheService.loadCached()
      └─> Load JSON from UserDefaults
      └─> JSONDecoder.decode(ParsedGraphic.self)
      └─> Return ParsedGraphic (NO PARSING!)
```

### 3. **Data Conversion** (`DocumentRendererView.swift`)
```
ParsedGraphic (from cache or fresh parse)
  └─> TactileScene.from(ParsedGraphic)
      └─> Convert back to TactileScene for rendering
```

### 4. **Rendering** (`TactileCanvasView.swift`)

**Layout:**
```
GeometryReader
  └─> Calculates canvas size from available space
  └─> Maintains aspect ratio from viewBox
```

**SwiftUI Canvas Rendering:**
```
Canvas { context, size in
  // 1. Calculate scale (fit viewBox to canvas size)
  scale = min(canvasWidth/viewBoxWidth, canvasHeight/viewBoxHeight)
  
  // 2. Transform coordinates (viewBox → canvas)
  transformPoint(point, size) {
    // Maps viewBox coordinates to canvas coordinates
    // Handles centering and scaling
  }
  
  // 3. Draw elements:
  ├─> Lines: context.stroke(path, lineWidth: scaledStrokeWidth)
  ├─> Polygons: context.fill() + context.stroke()
  ├─> Vertices: context.fill(ellipse) - black circles
  └─> Labels: context.draw(Text, at: position, anchor: .center)
}
```

**Coordinate Transformation:**
```swift
func transformPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
    let scaleX = size.width / viewBox.width
    let scaleY = size.height / viewBox.height
    let scale = min(scaleX, scaleY)  // Maintain aspect ratio
    
    // Center the content
    let offsetX = (size.width - viewBox.width * scale) / 2
    let offsetY = (size.height - viewBox.height * scale) / 2
    
    return CGPoint(
        x: (point.x - viewBox.origin.x) * scale + offsetX,
        y: (point.y - viewBox.origin.y) * scale + offsetY
    )
}
```

### 5. **Touch Interaction** (`TactileTouchOverlay.swift`)
```
UIKit Touch Tracking
  └─> Continuous touch tracking (not just taps)
  └─> Hit testing against lines, vertices, labels
  └─> Haptic feedback on intersections
  └─> VoiceOver announcements
```

## Key Components

### `TactileScene` (Runtime Model)
- `lineSegments: [TactileLineSegment]` - Lines with start/end points
- `labels: [TactileLabel]` - Text labels with positions
- `vertices: [TactileVertex]` - Corner points
- `viewBox: CGRect` - Original SVG dimensions

### `ParsedGraphic` (JSON Cache Model)
- Same structure as `TactileScene` but JSON-serializable
- `Point` instead of `CGPoint`
- `ViewBox` struct instead of `CGRect`
- `LabelAnchor` enum (above/left/right/diagonal)

### Label Positioning Logic
1. **During Parsing** (`associateLabelsWithLines`):
   - Find nearest line for each label
   - Adjust position based on line orientation:
     - Horizontal lines → position above (y = lineY - offset)
     - Vertical lines → position left (x = lineX - offset)
     - Diagonal lines → perpendicular offset

2. **During Rendering**:
   - Use adjusted positions from parsing
   - Transform to canvas coordinates
   - Draw with `context.draw(Text, at: position)`

## Performance

**First Run:**
- Parse SVG: ~50-100ms (depends on complexity)
- Cache JSON: ~5-10ms
- Render: ~16ms (60fps)

**Cached Runs:**
- Load JSON: ~1-2ms
- Render: ~16ms (60fps)

**Total Speedup:** ~10-50x faster on cached runs

## Current Issues (Being Fixed)

1. **Label Positioning:**
   - ✅ "35 in" now positioned above horizontal line
   - ✅ "50 in" keeps original position (far from vertical line)
   - ⚠️ Some labels still overlapping (e.g., "28 Yd" and "9 Yd" same y)

2. **Caching:**
   - ✅ Architecture in place
   - ✅ First run parses and caches
   - ⚠️ Need to verify cache is being used on subsequent runs
