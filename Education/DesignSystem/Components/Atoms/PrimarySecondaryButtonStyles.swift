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
            .font(.custom("Arial", size: 17).weight(.bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(ColorTokens.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .accessibilityAddTraits(.isButton)
            .contentShape(Rectangle())
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Arial", size: 17).weight(.bold))
            .foregroundColor(ColorTokens.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#DADDE2"), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .accessibilityAddTraits(.isButton)
            .contentShape(Rectangle())
    }
}
