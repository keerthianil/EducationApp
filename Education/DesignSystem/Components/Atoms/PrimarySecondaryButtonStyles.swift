//
//  PrimarySecondaryButtonStyles.swift
//  Education
//
//  Created by Keerthi Reddy on 11/7/25.
//

import Foundation
import SwiftUI

public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyBold)
            .foregroundColor(ColorTokens.buttonText)               // ⟵ was textLight
            .frame(maxWidth: .infinity)
            .frame(height: Spacing.buttonHeight)
            .background(ColorTokens.buttonPrimary)                  // brand teal
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .accessibilityAddTraits(.isButton)
            .contentShape(Rectangle())
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyBold)
            .foregroundColor(ColorTokens.buttonSecondaryText)       // ⟵ dynamic label color
            .frame(maxWidth: .infinity)
            .frame(height: Spacing.buttonHeight)
            .background(ColorTokens.buttonSecondary)                 // dynamic surface
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadius))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .accessibilityAddTraits(.isButton)
            .contentShape(Rectangle())
    }
}
