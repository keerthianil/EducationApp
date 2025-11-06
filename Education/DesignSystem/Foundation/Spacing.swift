//
//  Spacing.swift
//  Education
//
//  Spacing scale for StemA11y
//  Based on Figma design system using 4pt base grid
//

import SwiftUI

/// Spacing tokens for StemA11y
///
/// Provides consistent spacing values based on a 4-point grid system.
/// All values are multiples of 4 for visual rhythm and alignment.
///
/// Example usage:
/// ```swift
/// VStack(spacing: Spacing.small) {
///     Text("Hello")
/// }
/// .padding(Spacing.medium)
/// ```
public enum Spacing {
    
    // MARK: - Base Grid (4pt system)
    
    /// 4pt - Minimal spacing
    /// Use for: Tight padding, minimal gaps
    public static let xxSmall: CGFloat = 4
    
    /// 8pt - Extra small spacing
    /// Use for: Small gaps between related items, compact layouts
    public static let xSmall: CGFloat = 8
    
    /// 12pt - Small spacing
    /// Use for: Moderate gaps, form field spacing
    public static let small: CGFloat = 12
    
    /// 16pt - Medium spacing (most common)
    /// Use for: Standard padding, default gaps
    public static let medium: CGFloat = 16
    
    /// 20pt - Medium-large spacing
    /// Use for: Comfortable gaps between sections
    public static let mediumLarge: CGFloat = 20
    
    /// 24pt - Large spacing
    /// Use for: Section padding, comfortable gaps
    public static let large: CGFloat = 24
    
    /// 32pt - Extra large spacing
    /// Use for: Major sections, screen padding
    public static let xLarge: CGFloat = 32
    
    /// 48pt - Extra extra large spacing
    /// Use for: Major separations, hero sections
    public static let xxLarge: CGFloat = 48
    
    /// 64pt - Huge spacing
    /// Use for: Screen-level spacing
    public static let xxxLarge: CGFloat = 64
    
    /// 128pt - Massive spacing
    /// Use for: Navigation item spacing, large gaps
    public static let massive: CGFloat = 128
    
    // MARK: - Semantic Spacing
    
    /// Standard screen edge padding (24pt)
    /// Use for: Left/right padding on main content
    public static let screenPadding = large
    
    /// Standard horizontal padding (24pt)
    /// Use for: Leading/trailing padding
    public static let horizontalPadding = large
    
    /// Standard vertical padding (16pt)
    /// Use for: Top/bottom padding
    public static let verticalPadding = medium
    
    /// Spacing between sections (32pt)
    /// Use for: Gaps between major content sections
    public static let sectionSpacing = xLarge
    
    /// Spacing between related items (8pt)
    /// Use for: Items that belong together (list items, form fields)
    public static let itemSpacing = xSmall
    
    /// Spacing between groups (24pt)
    /// Use for: Separating distinct groups of content
    public static let groupSpacing = large
    
    // MARK: - Component Sizes
    
    /// Minimum touch target size (44pt)
    /// Apple's accessibility requirement for interactive elements
    public static let minTouchTarget: CGFloat = 44
    
    /// Standard button height (56pt)
    /// Comfortable tap target for primary actions
    public static let buttonHeight: CGFloat = 56
    
    /// Compact button height (44pt)
    /// Minimum size for buttons, meets accessibility
    public static let buttonHeightCompact: CGFloat = 44
    
    /// Text field height (56pt)
    /// Standard input field height
    public static let textFieldHeight: CGFloat = 56
    
    // MARK: - Corner Radius
    
    /// Small corner radius (8pt)
    /// Use for: Small buttons, badges, chips
    public static let cornerRadiusSmall: CGFloat = 8
    
    /// Standard corner radius (12pt)
    /// Use for: Buttons, cards, most rounded elements
    public static let cornerRadius: CGFloat = 12
    
    /// Large corner radius (16pt)
    /// Use for: Large cards, prominent elements
    public static let cornerRadiusLarge: CGFloat = 16
    
    /// Extra large corner radius (24pt)
    /// Use for: Hero cards, special emphasis
    public static let cornerRadiusXLarge: CGFloat = 24
    
    // MARK: - Border & Divider
    
    /// Standard border width (1pt)
    public static let borderWidth: CGFloat = 1
    
    /// Thick border width (2pt)
    public static let borderWidthThick: CGFloat = 2
    
    /// Divider height (1pt)
    public static let dividerHeight: CGFloat = 1
}

// MARK: - Padding Helpers

extension Spacing {
    /// Standard padding for all edges (24pt)
    public static var standardPadding: EdgeInsets {
        EdgeInsets(
            top: large,
            leading: large,
            bottom: large,
            trailing: large
        )
    }
    
    /// Screen padding (24pt horizontal, 16pt vertical)
    public static var screenInsets: EdgeInsets {
        EdgeInsets(
            top: medium,
            leading: large,
            bottom: medium,
            trailing: large
        )
    }
    
    /// Compact padding (12pt all sides)
    public static var compactPadding: EdgeInsets {
        EdgeInsets(
            top: small,
            leading: small,
            bottom: small,
            trailing: small
        )
    }
    
    /// Minimal padding (4pt all sides)
    public static var minimalPadding: EdgeInsets {
        EdgeInsets(
            top: xxSmall,
            leading: xxSmall,
            bottom: xxSmall,
            trailing: xxSmall
        )
    }
}