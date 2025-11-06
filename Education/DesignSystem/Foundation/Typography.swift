//
//  Typography.swift
//  Education
//
//  Typography scale for StemA11y
//  Based on Figma design system
//  All styles support Dynamic Type for accessibility
//

import SwiftUI

/// Typography tokens for StemA11y
///
/// Provides semantic text styles matching the Figma design system.
/// All styles automatically scale with Dynamic Type for accessibility.
///
/// Font Families Used:
/// - Verdana: Titles and headings
/// - Inter: Body text
/// - Arial: Secondary and small text
///
/// Example usage:
/// ```swift
/// Text("Welcome")
///     .font(Typography.largeTitle)
/// ```
public enum Typography {
    
    // MARK: - Titles (Verdana)
    
    /// Large Title - Page Title
    /// Verdana, Bold, 34pt
    /// Use for: Main page titles, hero text
    public static let largeTitle = Font.custom("Verdana-Bold", size: 34)
    
    /// Heading 1 - Title 1
    /// Verdana, SemiBold, 28pt
    /// Use for: Primary section titles
    public static let heading1 = Font.custom("Verdana", size: 28).weight(.semibold)
    
    /// Heading 2 - Title 2
    /// Verdana, Regular, 22pt
    /// Use for: Secondary section titles
    public static let heading2 = Font.custom("Verdana", size: 22)
    
    /// Heading 3 - Title 3
    /// Verdana, Regular, 20pt
    /// Use for: Tertiary headings
    public static let heading3 = Font.custom("Verdana", size: 20)
    
    // MARK: - Body Text
    
    /// Headline (Verdana)
    /// Verdana, SemiBold, 17pt
    /// Use for: Body text, paragraph text, links
    public static let headline = Font.custom("Verdana", size: 17).weight(.semibold)
    
    /// Body (Inter)
    /// Inter, Regular, 17pt
    /// Use for: Main content body text
    public static let body = Font.custom("Inter", size: 17)
    
    /// Body Bold
    /// Inter, SemiBold, 17pt
    /// Use for: Emphasized body text
    public static let bodyBold = Font.custom("Inter", size: 17).weight(.semibold)
    
    // MARK: - Secondary Text (Arial)
    
    /// Sub Head - Secondary Text
    /// Arial, Regular, 15pt
    /// Use for: Supporting text, descriptions
    public static let subheadline = Font.custom("Arial", size: 15)
    
    /// Footnote - Tertiary Text
    /// Arial, Regular, 13pt
    /// Use for: Captions, segmented buttons
    public static let footnote = Font.custom("Arial", size: 13)
    
    /// Caption
    /// Arial, Regular, 12pt
    /// Use for: Small labels, timestamps
    public static let caption1 = Font.custom("Arial", size: 12)
    
    /// Caption Small
    /// Arial, Regular, 11pt
    /// Use for: Very small text
    public static let caption2 = Font.custom("Arial", size: 11)
    
    /// Nav Bar - Tab Names
    /// Arial, SemiBold, 10pt
    /// Use for: Navigation tabs, smallest text
    public static let navBar = Font.custom("Arial", size: 10).weight(.semibold)
}

// MARK: - Dynamic Type Support

extension Typography {
    /// Typography styles with Dynamic Type scaling
    ///
    /// These variants automatically scale based on user's text size preference.
    /// Use these for better accessibility support.
    public enum Scaled {
        /// Large Title with scaling
        public static let largeTitle = Font.custom("Verdana-Bold", size: 34, relativeTo: .largeTitle)
        
        /// Heading 1 with scaling
        public static let heading1 = Font.custom("Verdana", size: 28, relativeTo: .title)
        
        /// Heading 2 with scaling
        public static let heading2 = Font.custom("Verdana", size: 22, relativeTo: .title2)
        
        /// Heading 3 with scaling
        public static let heading3 = Font.custom("Verdana", size: 20, relativeTo: .title3)
        
        /// Headline with scaling
        public static let headline = Font.custom("Verdana", size: 17, relativeTo: .headline)
        
        /// Body with scaling
        public static let body = Font.custom("Inter", size: 17, relativeTo: .body)
        
        /// Subheadline with scaling
        public static let subheadline = Font.custom("Arial", size: 15, relativeTo: .subheadline)
        
        /// Footnote with scaling
        public static let footnote = Font.custom("Arial", size: 13, relativeTo: .footnote)
        
        /// Caption with scaling
        public static let caption = Font.custom("Arial", size: 12, relativeTo: .caption)
    }
}

// MARK: - Text Color Helpers

extension Typography {
    /// Quick access to text colors with typography
    public enum TextColors {
        /// Primary text color (dark)
        public static let primary = ColorTokens.textPrimary
        
        /// Secondary text color
        public static let secondary = ColorTokens.textSecondary
        
        /// Tertiary text color
        public static let tertiary = ColorTokens.textTertiary
    }
}