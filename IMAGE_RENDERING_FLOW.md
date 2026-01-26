# Image Rendering Flow - Debug Guide

## Quick Summary

**What Renders What:**
- `WorksheetView` → Renders pages with nodes
- `NodeBlockView` → Wraps each node (heading, paragraph, image, SVG) in a white card
- `ImageBlockView` → Renders the actual image from base64 data URI

**Current Problem:**
- Ishows `Actual rendered frame: 0.0 x 350.0` in logsmage 
- Width is 0, so image can't render properly
- Height is correct (350pt = maxImageHeight)

**Root Cause:**
- `GeometryReader` in `ImageBlockView` is getting 0 width from parent
- This means `NodeBlockView`'s width constraints aren't reaching `ImageBlockView`

## Overview
This document explains how images are rendered in the Education app, from JSON data to the final displayed image.

## Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│  JSON File (sample2_page1.json)                        │
│  Contains: { "type": "image", "src": "data:image..." }│
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│  LessonStore.loadNodes(forFilenames:)                    │
│  └─> Parses JSON into [Node] array                      │
│      Node.image(src: "data:image/png;base64,...", alt)  │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│  WorksheetView                                          │
│  └─> ScrollView                                         │
│      └─> VStack (horizontalPadding: 24/48pt)            │
│          └─> ForEach(currentItems)                       │
│              └─> ForEach(item.nodes)                     │
│                  └─> NodeBlockView(node)  ← Container   │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│  NodeBlockView (WorksheetView.swift:289)                │
│  └─> VStack(alignment: .leading)                        │
│      └─> .padding(contentPadding)  ← 16/24pt padding   │
│      └─> .frame(maxWidth: .infinity)  ← Should provide │
│      └─> nodeContent (switch on node type)              │
│          └─> case .image:                                │
│              └─> ImageBlockView(dataURI, alt)            │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│  ImageBlockView (WorksheetView.swift:447)               │
│  └─> GeometryReader { geometry in                       │
│      │   geometry.size.width  ← Gets width from parent  │
│      │   geometry.size.height ← Gets height (maxImage)  │
│      └─> Image(uiImage: img)                            │
│          └─> .resizable()                                │
│          └─> .aspectRatio(contentMode: .fit)             │
│          └─> .frame(width: finalWidth, height: finalH)   │
│          └─> .frame(maxWidth: .infinity)                 │
│          └─> .frame(maxHeight: maxImageHeight)           │
└─────────────────────────────────────────────────────────┘
```

## Width Constraint Flow

```
Screen Width (402pt iPhone)
  └─> ScrollView (takes full width)
      └─> VStack with horizontalPadding (24pt iPhone)
          └─> Available: 402 - (24 * 2) = 354pt
              └─> NodeBlockView
                  └─> .frame(maxWidth: .infinity)  ← Should be 354pt
                      └─> .padding(contentPadding)  ← 16pt each side
                          └─> Available: 354 - (16 * 2) = 322pt
                              └─> VStack (nodeContent)
                                  └─> ImageBlockView
                                      └─> GeometryReader
                                          └─> geometry.size.width  ← Should be 322pt
```

**PROBLEM**: If `geometry.size.width` is 0.0, the constraint chain is broken somewhere above.

## Complete Rendering Flow

### 1. Data Loading (LessonStore.swift)
```
JSON File (sample2_page1.json)
  └─> LessonStore.loadNodes(forFilenames:)
      └─> LessonStore.loadBundleJSON(named:)
      └─> FlexibleLessonParser.parseNodes(from:)
          └─> Returns [Node] array
```

**Key Point**: Images come from JSON as `Node.image(src: String, alt: String?)` where `src` is a base64 data URI.

### 2. View Hierarchy (WorksheetView.swift)

```
WorksheetView (main view)
  └─> ScrollView
      └─> VStack
          └─> ForEach(currentItems) { item in
              └─> ForEach(item.nodes) { node in
                  └─> NodeBlockView(node: node)  ← Wraps each node
                      └─> VStack (with padding, background, border)
                          └─> nodeContent (switch on node type)
                              └─> case .image(let src, let alt):
                                  └─> ImageBlockView(dataURI: src, alt: alt)  ← YOUR IMAGE VIEW
```

### 3. NodeBlockView Container (WorksheetView.swift:289-313)

```swift
private struct NodeBlockView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            nodeContent  // Your ImageBlockView goes here
        }
        .padding(contentPadding)  // 16pt (iPhone) or 24pt (iPad)
        .frame(maxWidth: .infinity, alignment: .leading)  // ← Takes full width
        .background(Color.white)
        .overlay(RoundedRectangle...)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

**Key Constraints**:
- `.frame(maxWidth: .infinity)` - Should provide width to children
- `.padding(contentPadding)` - Adds padding (reduces available width)
- `VStack(alignment: .leading)` - Left-aligns content

### 4. ImageBlockView (WorksheetView.swift:447-506)

**Current Implementation**:
```swift
var body: some View {
    GeometryReader { geometry in
        // geometry.size.width should be: screenWidth - (padding * 2)
        if let img = decodeImage(dataURI: dataURI),
           let size = imageSize {
            let aspectRatio = size.width / size.height
            let availableWidth = geometry.size.width  // ← Gets width from parent
            let naturalHeight = availableWidth / aspectRatio
            let finalHeight = min(naturalHeight, maxImageHeight)
            let finalWidth = finalHeight * aspectRatio
            
            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: finalWidth, height: finalHeight)
                .frame(maxWidth: .infinity, maxHeight: maxImageHeight)
        }
    }
    .frame(height: maxImageHeight)  // ← Container height
}
```

**What Should Happen**:
1. `GeometryReader` gets width from `NodeBlockView` (minus padding)
2. Calculates height based on aspect ratio
3. Sets explicit frame dimensions
4. Image scales to fit

**Potential Issues**:
- If `geometry.size.width` is 0.0, the parent isn't providing width
- If `finalWidth` is calculated incorrectly, image might be wrong size
- If parent container has constraints that conflict

### 5. DocumentRendererView Flow (Similar)

```
DocumentRendererView
  └─> ScrollView
      └─> VStack
          └─> ForEach(filteredNodes) { node in
              └─> DocumentNodeView(node: node)
                  └─> switch node {
                      case .image(let src, let alt):
                          └─> DocumentImageView(dataURI: src, alt: alt)
```

**Note**: `DocumentNodeView` doesn't have a container like `NodeBlockView`, so images are directly in the VStack.

## Debugging Steps

### Step 1: Check GeometryReader Width
Add this to see what width the GeometryReader is getting:

```swift
GeometryReader { geometry in
    Color.clear
        .onAppear {
            print("[DEBUG] GeometryReader size: \(geometry.size)")
        }
    // ... your image code
}
```

### Step 2: Check Parent Container
Verify `NodeBlockView` is providing width:
- It has `.frame(maxWidth: .infinity)` ✓
- But check if there's something constraining it above

### Step 3: Check Image Decoding
Verify the image is being decoded correctly:
```swift
if let img = decodeImage(dataURI: dataURI) {
    print("[DEBUG] Decoded image size: \(img.size)")
} else {
    print("[DEBUG] ❌ Failed to decode image")
}
```

### Step 4: Check Frame Calculations
Add logs for each calculation step:
```swift
let availableWidth = geometry.size.width
let naturalHeight = availableWidth / aspectRatio
let finalHeight = min(naturalHeight, maxImageHeight)
let finalWidth = finalHeight * aspectRatio

print("[DEBUG] availableWidth: \(availableWidth)")
print("[DEBUG] naturalHeight: \(naturalHeight)")
print("[DEBUG] finalHeight: \(finalHeight)")
print("[DEBUG] finalWidth: \(finalWidth)")
```

### Step 5: Check Actual Rendered Size
Use GeometryReader in background to see actual size:
```swift
.background(
    GeometryReader { geo in
        Color.clear
            .onAppear {
                print("[DEBUG] Actual rendered: \(geo.size)")
            }
    }
)
```

## Common Issues & Solutions

### Issue 1: Width is 0.0
**Cause**: Parent container not providing width constraints
**Solution**: Ensure parent has `.frame(maxWidth: .infinity)` or explicit width

### Issue 2: Image is cropped
**Cause**: Height exceeds maxImageHeight but width isn't scaled down
**Solution**: Calculate scale factor and apply to both dimensions

### Issue 3: Image too small
**Cause**: Calculations using wrong width (screen vs available)
**Solution**: Use GeometryReader to get actual available width

### Issue 4: Image not visible
**Cause**: Frame dimensions are 0 or negative
**Solution**: Add guards: `guard availableWidth > 0 else { return }`

## Current Issue Analysis

Based on logs showing `Actual rendered frame: 0.0 x 350.0`:
- **Height**: 350.0 ✓ (correct, matches maxImageHeight)
- **Width**: 0.0 ✗ (problem!)

**Root Cause**: The GeometryReader is getting 0 width, which means:
1. Either the parent `NodeBlockView` isn't providing width
2. Or there's a constraint conflict preventing width propagation
3. Or the GeometryReader itself needs explicit width constraints

**Next Steps to Debug**:
1. Check if `NodeBlockView`'s VStack is actually getting width
2. Try adding `.frame(maxWidth: .infinity)` directly on ImageBlockView
3. Check if there are any `.fixedSize()` modifiers that might be preventing expansion
4. Verify the ScrollView and parent VStack are providing proper constraints
