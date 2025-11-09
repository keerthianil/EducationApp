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
            .foregroundColor(ColorTokens.textLight)
            .frame(maxWidth: .infinity)
            .frame(height: Spacing.buttonHeight)
            .background(ColorTokens.primary)
            .cornerRadius(Spacing.cornerRadius)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .accessibilityAddTraits(.isButton)
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.bodyBold)
            .foregroundColor(ColorTokens.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: Spacing.buttonHeight)
            .background(ColorTokens.surface1)
            .cornerRadius(Spacing.cornerRadius)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .accessibilityAddTraits(.isButton)
    }
}
