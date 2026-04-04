# StemAlly

An iOS/iPadOS accessibility app that makes STEM educational content accessible to blind and low-vision (BLV) students in grades 8-12. Part of a research assistantship project investigating multisensory representations of math equations, geometric diagrams, charts, and data tables.

## Research Context

BLV students face significant barriers accessing STEM worksheets that rely on visual content: equations, geometric figures, bar/line/pie charts, and data tables. StemAlly converts PDF worksheets into structured JSON and renders them with VoiceOver screen reader support, haptic feedback, spatial audio cues, and tactile touch exploration of graphics.

## Features

- **Math equations** with in-place exploration via custom VoiceOver rotor (MathML/LaTeX)
- **Geometric shapes** with fullscreen tactile touch exploration (4mm bold raised lines, haptic edges/vertices)
- **Bar charts, line graphs, pie charts** with fullscreen tactile exploration, AXChartDescriptor audio graphs, and custom VoiceOver rotors
- **Data tables** with cell-by-cell VoiceOver navigation and row rotor
- **Data table alternative** toggle on every chart (switch between visual and tabular)
- **Interaction logging** for research data collection (CSV/Excel/PDF export)
- **iPad and iPhone** responsive layouts

## Architecture

```
Education/
  App/           AppState, EducationApp (entry point)
  Core/
    Models/      Node enum, FlexibleLessonParser, WorksheetItem
    Services/    HapticService, SpeechService, MathSpeechService,
                 InteractionLogger, LessonStore, AudioCueService
  DesignSystem/  ColorTokens, Spacing, Typography, PhysicalDimensions
  Features/
    Home/        DashboardView (single dashboard with upload + lessons)
    Onboarding/  AboutView, AuthenticationView, IntroOnboardingView
    Reader/
      Math/      MathAccessibilityElement (rotor), MathMLView, MathParser
      Charts/    BarChartBlockView, LineGraphBlockView, PieChartBlockView,
                 TableBlockView, MultisensoryChartView
      ...        DocumentRendererView, MultisensorySVGView, SVGView
  Resources/
    raw_json/    Lesson JSON files organized by content type
```

### Content Pipeline

```
JSON file  -->  FlexibleLessonParser  -->  [Node]  -->  DocumentRendererView / WorksheetView
                                                              |
                                    Renders: headings, paragraphs, math, SVG, charts, tables
```

Node types: `heading`, `paragraph`, `image`, `svgNode`, `mapNode`, `barChart`, `lineGraph`, `pieChart`, `tableNode`

## VoiceOver Interaction Patterns

The app uses a consistent two-tier interaction model:

| Tier | Content | Interaction | Exit |
|------|---------|-------------|------|
| **In-place** | Math equations | Double-tap to enter math mode, "Equation parts" rotor to navigate terms | Two-finger scrub |
| **Fullscreen explore** | SVG graphics, all chart types | Double-tap to open tactile canvas, touch to explore with 4mm bold lines + haptics | Three-finger swipe |

### Fullscreen Tactile Exploration (Graphics + Charts)

All fullscreen views use device-independent physical measurements via `PhysicalDimensions.mmToPoints()`:
- **Geometric shape edges:** 4mm bold stroke (rectangles, triangles, etc.)
- **Line graph data lines:** 3mm stroke (bold enough to trace, preserves data shape)
- **Bar outlines:** Thin 1.5pt (bars identified by fill color, not outline)
- **Pie slice separators:** 2mm white dividers
- **Data points/vertices:** 6mm red dots (BANA minimum)
- **Haptics:** Continuous vibration on lines/areas, pulsing + audio ding on data points
- **Exit:** Three-finger swipe or VoiceOver escape

### Chart Block Views (Before Fullscreen)

Each chart type provides VoiceOver navigation without needing to open fullscreen:
- **Summary announcement** on focus (e.g., "Bar chart with 5 bars. Highest: All at 18.")
- **Custom rotors:** "Bars", "Data Points", "Slices", "Rows" for element-by-element navigation
- **AXChartDescriptor** for iOS Audio Graphs (sonification via VoiceOver actions, iOS 15+)
- **Data table toggle** to switch between chart and tabular representation

## Requirements

- Xcode 15+
- iOS 16+ / iPadOS 16+
- Swift 5.9+
- ZIPFoundation 0.9.20 (SPM dependency)

## Getting Started

1. Open `Education.xcodeproj` in Xcode
2. Select a simulator or device and run (Cmd+R)
3. First launch shows onboarding, then the dashboard with lesson cards
4. Tap any lesson to open the reader

## VoiceOver Testing

1. **Simulator:** Features > Accessibility > VoiceOver (or Cmd+F5 on newer Xcode)
2. **Device:** Settings > Accessibility > VoiceOver
3. **Navigate:** Swipe right to move through elements
4. **Rotors:** Two-finger twist to select a rotor (Bars, Data Points, Slices, Rows, Equation parts)
5. **Fullscreen explore:** Double-tap a chart or graphic, then touch and drag to explore
6. **Audio Graph:** Focus a chart, use VoiceOver actions (swipe up/down) to find "Play Audio Graph"
7. **Exit fullscreen:** Three-finger swipe left/right, or two-finger scrub (Z gesture)

## Interaction Logging

All touch events, VoiceOver interactions, and navigation are logged via `InteractionLogger`. Tap the gear icon on the dashboard to export logs as Excel or PDF for research analysis.

## License

Research project - not for redistribution.
