//
//  ColorTokens.swift
//  Education
//
//  Color palette for StemA11y
//  Based on Figma design system
//  Created: November 2024
//

import SwiftUI

/// Semantic color tokens for StemA11y
///
/// All colors are defined from the Figma design system.
/// Use semantic naming (primary, error) rather than appearance-based naming (teal, red).
///
/// Example usage:
/// ```swift
/// Text("Hello")
///     .foregroundColor(ColorTokens.textPrimary)
///
/// Button("Continue") { }
///     .background(ColorTokens.primary)
/// ```
public enum ColorTokens {
    
    // MARK: - Primary Colors (Teal/Cyan)
    
    /// Primary brand color - Dark Teal
    /// Hex: #1C636F
    /// Use for: Main actions, primary buttons, brand emphasis
    public static let primary = Color(hex: "#1C636F")
    
    /// Primary color tint 1 - Medium Teal
    /// Hex: #6FA9B3
    /// Use for: Hover states, secondary elements
    public static let primaryLight1 = Color(hex: "#6FA9B3")
    
    /// Primary color tint 2 - Light Teal
    /// Hex: #A5CDD3
    /// Use for: Backgrounds, highlights
    public static let primaryLight2 = Color(hex: "#A5CDD3")
    
    /// Primary color tint 3 - Very Light Teal
    /// Hex: #DCF0F2
    /// Use for: Subtle backgrounds, disabled states
    public static let primaryLight3 = Color(hex: "#DCF0F2")
    
    // MARK: - Secondary Colors - Pink/Magenta
    
    /// Secondary color - Dark Magenta
    /// Hex: #9C265D
    /// Use for: Secondary actions, variety in UI, user profiles
    public static let secondaryPink = Color(hex: "#9C265D")
    
    /// Secondary pink tint 1 - Medium Pink
    /// Hex: #D96FA5
    public static let secondaryPinkLight1 = Color(hex: "#D96FA5")
    
    /// Secondary pink tint 2 - Light Pink
    /// Hex: #E89FC2
    public static let secondaryPinkLight2 = Color(hex: "#E89FC2")
    
    /// Secondary pink tint 3 - Very Light Pink
    /// Hex: #F8D9E9
    public static let secondaryPinkLight3 = Color(hex: "#F8D9E9")
    
    // MARK: - Secondary Colors - Purple
    
    /// Secondary color - Dark Purple
    /// Hex: #332177
    /// Use for: Alternative accent, premium features, settings
    public static let secondaryPurple = Color(hex: "#332177")
    
    /// Secondary purple tint 1 - Medium Purple
    /// Hex: #8074AF
    public static let secondaryPurpleLight1 = Color(hex: "#8074AF")
    
    /// Secondary purple tint 2 - Light Purple
    /// Hex: #AEA5CF
    public static let secondaryPurpleLight2 = Color(hex: "#AEA5CF")
    
    /// Secondary purple tint 3 - Very Light Purple
    /// Hex: #E7E3F4
    public static let secondaryPurpleLight3 = Color(hex: "#E7E3F4")
    
    // MARK: - Secondary Colors - Blue
    
    /// Secondary color - Dark Blue
    /// Hex: #244561
    /// Use for: Additional accent, information states
    public static let secondaryBlue = Color(hex: "#244561")
    
    /// Secondary blue tint 1 - Medium Blue
    /// Hex: #7C9DB3
    public static let secondaryBlueLight1 = Color(hex: "#7C9DB3")
    
    /// Secondary blue tint 2 - Light Blue
    /// Hex: #ADC4D3
    public static let secondaryBlueLight2 = Color(hex: "#ADC4D3")
    
    /// Secondary blue tint 3 - Very Light Blue
    /// Hex: #CEDEE8
    public static let secondaryBlueLight3 = Color(hex: "#CEDEE8")
    
    // MARK: - Semantic/Feedback Colors
    
    /// Success state - positive feedback
    /// Hex: #208515
    /// Use for: Success messages, positive confirmations, completed states
    public static let success = Color(hex: "#208515")
    
    /// Error state - warnings and errors
    /// Hex: #B31111
    /// Use for: Error messages, validation failures, destructive actions
    public static let error = Color(hex: "#B31111")
    
    /// Warning state - cautionary messages
    /// Hex: #FFB921
    /// Use for: Warning messages, important notices, attention needed
    public static let warning = Color(hex: "#FFB921")
    
    /// Info state - informational messages
    /// Hex: #214F9A
    /// Use for: Informational messages, tips, helpful hints
    public static let info = Color(hex: "#214F9A")
    
    // MARK: - Neutral Colors
    
    /// Background color (light mode)
    /// Hex: #F5F5F5
    /// Use for: Main screen background
    public static let background = Color(hex: "#F5F5F5")
    
    /// Surface color 1 - cards and elevated content
    /// Hex: #ECECEC
    /// Use for: Cards, buttons, first level of elevation
    public static let surface1 = Color(hex: "#ECECEC")
    
    /// Surface color 2 - nested content
    /// Hex: #E3E3E3
    /// Use for: Nested cards, second level of elevation
    public static let surface2 = Color(hex: "#E3E3E3")
    
    /// Text color dark - main text
    /// Hex: #212121
    /// Use for: Primary text on light backgrounds
    public static let textDark = Color(hex: "#212121")
    
    /// Text color light - text on dark backgrounds
    /// Use for: Text on dark backgrounds, buttons with colored backgrounds
    public static let textLight = Color.white
    
    // MARK: - Semantic Text Colors
    
    /// Primary text color - main content
    /// Full opacity of textDark
    /// Use for: Headings, body text, important content
    public static let textPrimary = textDark
    
    /// Secondary text color - less important content
    /// 70% opacity of textDark
    /// Use for: Descriptions, supporting text, secondary information
    public static let textSecondary = textDark.opacity(0.7)
    
    /// Tertiary text color - hints and disabled states
    /// 50% opacity of textDark
    /// Use for: Placeholder text, disabled text, hints
    public static let textTertiary = textDark.opacity(0.5)
    
    // MARK: - UI Element Colors
    
    /// Border color for outlined elements
    /// Hex: #E3E3E3
    /// Use for: Input borders, card outlines, dividers
    public static let border = Color(hex: "#E3E3E3")
    
    /// Separator lines between content
    /// Hex: #ECECEC
    /// Use for: List separators, section dividers
    public static let separator = Color(hex: "#ECECEC")
    
    /// Disabled state background
    /// Hex: #ECECEC
    /// Use for: Disabled buttons, inactive elements
    public static let disabled = Color(hex: "#ECECEC")
    
    // MARK: - Convenience Accessors
    
    /// Default button background color
    public static let buttonPrimary = primary
    
    /// Default button text color
    public static let buttonText = textLight
    
    /// Secondary button background
    public static let buttonSecondary = surface1
    
    /// Secondary button text
    public static let buttonSecondaryText = textPrimary
}

// MARK: - Color Extension for Hex Support

extension Color {
    /// Creates a color from a hex string
    ///
    /// Supports multiple hex formats:
    /// - "#RGB" (12-bit)
    /// - "#RRGGBB" (24-bit)
    /// - "#RRGGBBAA" (32-bit with alpha)
    ///
    /// Example:
    /// ```swift
    /// let teal = Color(hex: "#1C636F")
    /// let tealWithAlpha = Color(hex: "#1C636F80")
    /// ```
    ///
    /// - Parameter hex: Hex color string (with or without # prefix)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RRGGBB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // RRGGBBAA (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview Helper

#if DEBUG
struct ColorTokens_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Primary Colors
                ColorSection(title: "Primary Colors") {
                    ColorSwatch(name: "Primary", color: ColorTokens.primary, hex: "#1C636F")
                    ColorSwatch(name: "Primary Light 1", color: ColorTokens.primaryLight1, hex: "#6FA9B3")
                    ColorSwatch(name: "Primary Light 2", color: ColorTokens.primaryLight2, hex: "#A5CDD3")
                    ColorSwatch(name: "Primary Light 3", color: ColorTokens.primaryLight3, hex: "#DCF0F2")
                }
                
                // Secondary Pink
                ColorSection(title: "Secondary - Pink") {
                    ColorSwatch(name: "Secondary Pink", color: ColorTokens.secondaryPink, hex: "#9C265D")
                    ColorSwatch(name: "Pink Light 1", color: ColorTokens.secondaryPinkLight1, hex: "#D96FA5")
                    ColorSwatch(name: "Pink Light 2", color: ColorTokens.secondaryPinkLight2, hex: "#E89FC2")
                    ColorSwatch(name: "Pink Light 3", color: ColorTokens.secondaryPinkLight3, hex: "#F8D9E9")
                }
                
                // Semantic Colors
                ColorSection(title: "Semantic Colors") {
                    ColorSwatch(name: "Success", color: ColorTokens.success, hex: "#208515")
                    ColorSwatch(name: "Error", color: ColorTokens.error, hex: "#B31111")
                    ColorSwatch(name: "Warning", color: ColorTokens.warning, hex: "#FFB921")
                    ColorSwatch(name: "Info", color: ColorTokens.info, hex: "#214F9A")
                }
                
                // Neutral Colors
                ColorSection(title: "Neutral Colors") {
                    ColorSwatch(name: "Background", color: ColorTokens.background, hex: "#F5F5F5")
                    ColorSwatch(name: "Surface 1", color: ColorTokens.surface1, hex: "#ECECEC")
                    ColorSwatch(name: "Surface 2", color: ColorTokens.surface2, hex: "#E3E3E3")
                    ColorSwatch(name: "Text Dark", color: ColorTokens.textDark, hex: "#212121")
                }
            }
            .padding()
        }
        .background(ColorTokens.background)
    }
    
    struct ColorSection<Content: View>: View {
        let title: String
        let content: Content
        
        init(title: String, @ViewBuilder content: () -> Content) {
            self.title = title
            self.content = content()
        }
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(ColorTokens.textPrimary)
                
                VStack(spacing: 8) {
                    content
                }
            }
        }
    }
    
    struct ColorSwatch: View {
        let name: String
        let color: Color
        let hex: String
        
        var body: some View {
            HStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 60, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline)
                        .foregroundColor(ColorTokens.textPrimary)
                    Text(hex)
                        .font(.caption)
                        .foregroundColor(ColorTokens.textSecondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(ColorTokens.surface1)
            .cornerRadius(8)
        }
    }
}
#endif

