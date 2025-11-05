//
//  TestHomeView.swift
//  Education
//
//  Test view to verify Design System works
//

import SwiftUI

struct TestHomeView: View {
    var body: some View {
        ZStack {
            // Background
            ColorTokens.background
                .ignoresSafeArea()
            
            // Content
            VStack(spacing: Spacing.large) {
                // Title
                Text("Welcome to StemA11y")
                    .font(Typography.largeTitle)
                    .foregroundColor(ColorTokens.textPrimary)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text("Testing our Design System")
                    .font(Typography.body)
                    .foregroundColor(ColorTokens.textSecondary)
                
                Spacer()
                    .frame(height: Spacing.xLarge)
                
                // Color Swatches
                VStack(spacing: Spacing.medium) {
                    ColorRow(title: "Primary", color: ColorTokens.primary)
                    ColorRow(title: "Success", color: ColorTokens.success)
                    ColorRow(title: "Error", color: ColorTokens.error)
                    ColorRow(title: "Warning", color: ColorTokens.warning)
                }
                
                Spacer()
                
                // Test Buttons
                VStack(spacing: Spacing.small) {
                    Button("Primary Button") {
                        print("Primary tapped!")
                    }
                    .foregroundColor(ColorTokens.textLight)
                    .frame(maxWidth: .infinity)
                    .frame(height: Spacing.buttonHeight)
                    .background(ColorTokens.primary)
                    .cornerRadius(Spacing.cornerRadius)
                    
                    Button("Secondary Button") {
                        print("Secondary tapped!")
                    }
                    .foregroundColor(ColorTokens.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: Spacing.buttonHeight)
                    .background(ColorTokens.surface1)
                    .cornerRadius(Spacing.cornerRadius)
                }
            }
            .padding(Spacing.screenPadding)
        }
    }
}

// Helper view for color swatches
struct ColorRow: View {
    let title: String
    let color: Color
    
    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: Spacing.cornerRadiusSmall)
                .fill(color)
                .frame(width: 50, height: 50)
            
            Text(title)
                .font(Typography.body)
                .foregroundColor(ColorTokens.textPrimary)
            
            Spacer()
        }
        .padding(Spacing.small)
        .background(ColorTokens.surface1)
        .cornerRadius(Spacing.cornerRadius)
    }
}

#Preview {
    TestHomeView()
}