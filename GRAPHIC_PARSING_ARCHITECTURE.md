# Graphic Parsing Architecture

## Overview

This document describes the new clean architecture for parsing and rendering SVG graphics. The architecture separates parsing from rendering, making the code more maintainable and debuggable.

## Architecture

### 1. Data Model (`ParsedGraphicModel.swift`)

**ParsedGraphic**: JSON-serializable model containing:
- `viewBox`: The SVG viewBox dimensions
- `lines`: Array of `ParsedLine` (with orientation: horizontal/vertical/diagonal)
- `labels`: Array of `ParsedLabel` (with anchor: above/left/right/diagonal)
- `vertices`: Array of `ParsedVertex`
- `title` and `description`: Optional metadata

**Key Benefits**:
- Clean, explicit data structure
- JSON-serializable (can be cached/saved)
- Type-safe with clear semantics

### 2. Parser Service (`GraphicParserService.swift`)

**GraphicParserService.parse(svgContent:)**:
- Parses SVG string once into `ParsedGraphic`
- Handles text cleaning (OCR fixes, unit normalization)
- Determines line orientations
- Positions labels with proper anchors
- Combines nearby number+unit labels

**Key Features**:
- Simple, focused parsing logic
- No rendering concerns
- Easy to test and debug
- Can be extended to save/load JSON

### 3. Renderer (`SimpleGraphicView.swift`)

**SimpleGraphicView**:
- Takes `ParsedGraphic` as input
- Renders lines, vertices, and labels
- Adjusts label positions based on anchor
- Handles scaling and aspect ratio

**Key Benefits**:
- No parsing logic in renderer
- Predictable rendering
- Easy to modify visual appearance

## Usage

### Basic Usage

```swift
// Parse SVG once
if let parsed = GraphicParserService.parse(svgContent: svgString) {
    // Render using SimpleGraphicView
    SimpleGraphicView(parsedGraphic: parsed)
    
    // Or convert to TactileScene for existing renderer
    let scene = TactileScene.from(parsed)
    TactileCanvasView(scene: scene, ...)
}
```

### JSON Serialization (Future)

```swift
// Save parsed graphic to JSON
let encoder = JSONEncoder()
if let data = try? encoder.encode(parsedGraphic) {
    // Save to file/cache
}

// Load from JSON
let decoder = JSONDecoder()
if let loaded = try? decoder.decode(ParsedGraphic.self, from: data) {
    // Use loaded graphic
}
```

## Migration Path

1. **Current**: `DocumentRendererView` uses new parser with fallback to old parser
2. **Next**: Test new parser, fix any edge cases
3. **Future**: Remove old parser, add JSON caching

## Benefits

1. **Separation of Concerns**: Parsing and rendering are separate
2. **Maintainability**: Cleaner, easier to understand code
3. **Debuggability**: Can inspect `ParsedGraphic` directly
4. **Testability**: Parser can be tested independently
5. **Performance**: Can cache parsed graphics as JSON
6. **Flexibility**: Easy to add new features (e.g., label positioning rules)

## Label Positioning

Labels are positioned based on their `anchor` property:
- **`.above`**: For horizontal lines, positioned above the line
- **`.left`**: For vertical lines, positioned to the left
- **`.right`**: For vertical lines, positioned to the right (alternative)
- **`.diagonal`**: For diagonal lines, positioned with small offset

The anchor is determined during parsing based on the nearest line's orientation.

## Text Combining

The parser combines nearby labels:
- Numbers (e.g., "35") + Units (e.g., "in") → "35 in"
- Handles OCR errors (e.g., "50n" → "50 in")
- Normalizes unit casing ("IN" → "in")
