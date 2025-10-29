# EducationApp

Accessibility-first iOS/iPadOS application for BLV (blind and low-vision) learners.  
Initial scope implements the onboarding flow (About → Login/Register → Profile Name → Profile Age → Tutorial → Home) exactly as designed in Figma, with VoiceOver compatibility, Dynamic Type, text-to-speech, and haptic feedback scaffolding.

## Table of Contents
- [Features](#features)
- [Architecture](#architecture)
- [Accessibility](#accessibility)
- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Running & Testing](#running--testing)
- [Branching & Releases](#branching--releases)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [License](#license)

## Features
- VoiceOver-first onboarding screens with correct headings, focus order, and hints.
- Dynamic Type and large hit targets (≥44pt).
- Text-to-speech via AVFoundation (with comfortable default rate).
- Core Haptics patterns for math/chem events (start/term/end, bond, success, error).
- Math speech stub with brief/verbose options (replace with real MathML/LaTeX parser later).
- iPhone and iPad layout support.

## Architecture
- **SwiftUI + MVVM**
  - `Views/` (SwiftUI structs): present state.
  - `ViewModels/` (ObservableObject classes): business/UI logic.
  - `Models/` (structs): app data, Codable.
  - `Services/` (final classes): Speech/Haptics/Math/AudioCue, injected via environment.
- Single source of navigation truth in `App/AppState.swift`.

## Accessibility
- Page titles marked as `.accessibilityHeading(.h1)`.
- VoiceOver announcements on screen appear (steps, context).
- All actionable elements have labels and hints; decorative images are hidden from a11y.
- Respects Dynamic Type, Reduce Motion, and adaptive colors for Dark Mode.
- Roadmap
    •    Phase 2: Math Speech Engine (real parser), Settings (verbosity/rate/haptic intensity).
    •    Phase 3: PDF → JSON ingestion, diagram exploration with spatial audio, Firebase Auth/Storage.
    •    Research logging (export JSON/CSV), braille display support.


## Requirements
- Xcode 15 or newer
- iOS 17+ (can lower to 16.4 if needed)
- Swift 5.9+

## Getting Started
1. Open `Education.xcodeproj` in Xcode.
2. Select a simulator (iPhone 15 or iPad Air) and run `⌘R`.
3. Enable VoiceOver in the Simulator: **Features → Accessibility → VoiceOver**.
4. Explore onboarding; try “Speak Equation” in Tutorial to test TTS + haptics.

## Running & Testing
- **Clean build folder:** `Shift + Cmd + K`
- **Erase simulator content (if needed):** Simulator → Settings → Erase All Content and Settings

