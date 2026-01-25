# SVG Graphic Rendering Flow - Required Files

This document lists all files required to handle SVG graphic rendering with tactile support for blind users.

## 📁 Core Files (Required)

### 1. **SVG Rendering Views** (3 files)
These files handle the actual rendering of SVG graphics:

- **`Education/Features/Reader/SVGKitView.swift`** ⭐ NEW
  - Native SVG rendering using SVGKit library
  - Handles decorative SVGs (non-tactile)
  - Falls back to WKWebView if SVGKit unavailable
  - **Purpose**: Proper text rendering, coordinates, styling without manual parsing

- **`Education/Features/Reader/SVGView.swift`**
  - WKWebView-based SVG rendering (legacy/fallback)
  - Used when SVGKit is not available
  - **Purpose**: Backup rendering method

- **`Education/Features/Reader/TactileCanvasView.swift`** ⭐ CORE
  - SwiftUI Canvas-based rendering for tactile graphics
  - Provides touch interaction, haptics, VoiceOver announcements
  - Handles double-tap to open multisensory view
  - **Purpose**: Interactive tactile exploration for blind users

### 2. **Tactile Graphics System** (4 files)
These files enable touch-based exploration:

- **`Education/Core/Models/TactileGraphics.swift`**
  - Data models: `TactileScene`, `TactileLineSegment`, `TactilePolygon`, `TactileVertex`, `TactileLabel`
  - Hit-testing logic and progress calculation
  - **Purpose**: Core data structures for tactile graphics

- **`Education/Core/Services/SVGToTactileParser.swift`**
  - Parses SVG content to extract geometric elements (lines, circles, text)
  - Builds connectivity graph and associates labels
  - **Purpose**: Converts SVG to tactile scene for interaction

- **`Education/Core/Services/TactileHapticEngine.swift`**
  - Haptic feedback patterns (continuous, pulse, selection)
  - Works with VoiceOver enabled
  - **Purpose**: Provides tactile feedback during exploration

- **`Education/Features/Reader/TactileTouchOverlay.swift`**
  - UIKit-based touch tracking overlay
  - Enables continuous touch tracking (not possible with SwiftUI gestures alone)
  - **Purpose**: Captures touch events for tactile interaction

### 3. **Multisensory View** (1 file)
Enhanced exploration mode:

- **`Education/Features/Reader/MultisensoryTactileView.swift`**
  - Full-screen tactile exploration view
  - Thicker lines, larger vertices, audio feedback
  - Opens on double-tap from TactileCanvasView
  - **Purpose**: Enhanced exploration for complex graphics

### 4. **Integration Points** (2 files)
These files decide which rendering method to use:

- **`Education/Features/Reader/DocumentRendererView.swift`** ⭐ INTEGRATION
  - Main document renderer
  - Contains `DocumentSVGView` which:
    - Detects if SVG has geometric elements (lines, circles)
    - Routes to `TactileCanvasView` for geometric diagrams
    - Routes to `SVGKitView` for decorative SVGs
  - **Purpose**: Smart routing between tactile and decorative rendering

- **`Education/Features/WorksheetView.swift`**
  - Worksheet renderer (similar logic to DocumentRendererView)
  - Also contains `SVGBlockView` for SVG rendering in worksheets
  - **Purpose**: SVG rendering in worksheet context

### 5. **Data Models** (1 file)
JSON parsing:

- **`Education/Core/Models/LessonModels.swift`**
  - Defines `Node.svgNode` case
  - Parses SVG content from JSON
  - **Purpose**: Extracts SVG data from lesson JSON files

---

## 🔄 Flow Diagram

```
JSON File (svgNode)
    ↓
LessonModels.swift (parses JSON)
    ↓
DocumentRendererView.swift / WorksheetView.swift
    ↓
DocumentSVGView / SVGBlockView
    ↓
    ├─→ Has geometric elements? (lines, circles)
    │   ↓ YES
    │   SVGToTactileParser.swift
    │   ↓
    │   TactileGraphics.swift (creates TactileScene)
    │   ↓
    │   TactileCanvasView.swift
    │   ├─→ TactileTouchOverlay.swift (touch tracking)
    │   ├─→ TactileHapticEngine.swift (haptics)
    │   └─→ MultisensoryTactileView.swift (double-tap)
    │
    └─→ NO (decorative SVG)
        ↓
        SVGKitView.swift (or SVGView.swift fallback)
```

---

## 📦 Dependencies

### External Package:
- **SVGKit** (via Swift Package Manager)
  - URL: `https://github.com/SVGKit/SVGKit.git`
  - **Required for**: Native SVG rendering in `SVGKitView.swift`
  - **Fallback**: WKWebView if not available

### System Frameworks:
- `SwiftUI` - UI framework
- `UIKit` - Touch handling, haptics
- `WebKit` - Fallback SVG rendering
- `AudioToolbox` - Sound feedback
- `ObjectiveC` - Associated objects for SVGKit

---

## 🎯 Key Decision Points

### When to use TactileCanvasView:
- SVG contains `<line>`, `<circle>`, or `<polygon>` elements
- User needs touch interaction (haptics, VoiceOver)
- Graphic is a geometric diagram (not decorative)

### When to use SVGKitView:
- SVG is decorative (no geometric elements)
- Or geometric parsing fails
- Needs proper text rendering (periods, special characters)

---

## 🔧 Files Modified in Recent Changes

1. ✅ `SVGKitView.swift` - Created (new SVGKit integration)
2. ✅ `DocumentRendererView.swift` - Updated (uses SVGKitView)
3. ✅ `TactileCanvasView.swift` - Updated (removed duplicate title)
4. ✅ `SVGToTactileParser.swift` - Updated (text combination, duplicate removal)
5. ✅ `TactileHapticEngine.swift` - Updated (VoiceOver compatibility, sounds)
6. ✅ `TactileGraphics.swift` - Updated (progress calculation)

---

## 📝 Summary

**Total Files: 11 core files**

- **3** SVG rendering views
- **4** Tactile graphics system files
- **1** Multisensory view
- **2** Integration points
- **1** Data model

All files work together to provide:
- ✅ Proper SVG rendering (via SVGKit)
- ✅ Tactile interaction for blind users
- ✅ Haptic feedback with VoiceOver
- ✅ Progress-based announcements
- ✅ Multisensory exploration mode
